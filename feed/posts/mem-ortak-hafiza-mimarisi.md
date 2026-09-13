---
title: "mem.agentandbot.com: AI Ajanlar İçin Hibrit Ortak Hafıza Katmanı ve Semantik Bilgi Üssü"
date: 2026-08-31
author: "İlker İpçioğlu & AgentAndBot Ekibi"
sites: [agentandbot, e-any, ipcioglu]
tags: [mem, agentandbot, memory, pgvector, hybrid-search, mcp, ai-agents, architecture]
excerpt: "Konuşmalar geçici, çıktılar ve kurumsal bilgi kalıcıdır. AgentAndBot çoklu ajan ağı (Hermes, Sara, OpenCode) için geliştirdiğimiz hibrit semantik hafıza mimarisi, RRF füzyon araması ve MCP entegrasyonunun derinlemesine analizi."
---

Yapay zeka ajanlarıyla (AI Agents) çalışırken karşılaşılan en büyük paradoks **hafıza kaybıdır**. Bir ajan oturumu açılır, saatlerce derin bir mimari tartışılır, çözümler üretilir ve oturum kapandığında her şey sıfırlanır. Ajan bir sonraki göreve "japon balığı hafızasıyla" başlar; aynı hatalara tekrar düşer, daha önce verilmiş kararları bilmez ve ekip arkadaşı olan diğer ajanların ne yaptığından habersizdir.

Bu problemi çözmek için **AgentAndBot** platformunun kalbine merkezi bir kurumsal bilgi ve hafıza katmanı yerleştirdik: **[mem.agentandbot.com](https://mem.agentandbot.com)**.

Platformumuzun temel tasarım felsefesi çok nettir:  
> **"Conversation is temporary. Artifact is the product."** *(Konuşma geçicidir, üretilen ürün ve bilgi kalıcıdır.)*

Bu yazıda; **mem** servisinin arkasındaki hibrit arama (RRF) mimarisini, lokal vektör embedder altyapısını, Model Context Protocol (MCP) bağlantılarını ve çoklu ajan ağımızın (Hermes + Sara + OpenCode) bu ortak hafızayı nasıl kullandığını inceliyoruz.

---

## 🏛️ Mimari Genel Bakış: İki Katmanlı Bellek Modeli (Two-Tier Memory)

Tek tip bir hafıza yapısı her ihtiyacı karşılayamaz. Bir geliştiricinin "Ben Elixir kullanıyorum" gibi anlık tercihi ile, 50 sayfalık SAP entegrasyon spesifikasyonu aynı çuvala atılamaz. Bu yüzden hafızayı iki katmana ayırdık:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      AGENTANDBOT HAFIZA KATMANI                         │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
         ┌───────────────────────────┴───────────────────────────┐
         ▼                                                       ▼
┌─────────────────────────────────┐             ┌─────────────────────────────────┐
│     1. KİŞİSEL / ANLIK BELLEK   │             │   2. KURUMSAL ORTAK HAFIZA      │
│         (Personal Facts)        │             │      (Enterprise Knowledge)     │
├─────────────────────────────────┤             ├─────────────────────────────────┤
│ • Kullanıcı tercihleri & tarzı  │             │ • Mimari kararlar & tasarımlar  │
│ • Anlık kural & bağlamlar       │             │ • Kod repo dokümanları & API'lar│
│ • Kısa fact extraction          │             │ • Hata teşhisleri & çözümler    │
│ • Katman: Mem0 / Local Profile  │             │ • Katman: mem.agentandbot.com   │
└─────────────────────────────────┘             └─────────────────────────────────┘
```

1. **Kişisel Katman (User Profile & Facts):** Kullanıcının iletişim dili, çalışma tarzı, rolleri ve anlık tercihleri gibi kompakt bilgileri barındırır.
2. **Kurumsal Bilgi Üssü (`mem.agentandbot.com`):** Tüm repoların, dokümanların, toplantı çıktılarının, çözülen kritik bug'ların ve ajan müzakerelerinin arşivlendiği, semantik olarak taranabilir devasa bilgi deposu.

---

## 🔍 Hibrit Arama Motoru (RRF Fusion Search)

Sadece kelime bazlı (Full-Text) arama yetersizdir çünkü eş anlamlıları ve niyeti kaçırır. Sadece vektör (Semantic Vector) arama da tek başına yetersizdir çünkü özel terimleri, fonksiyon adlarını (`AuthPlug.verify/2`) veya tam kod bloklarını ıskalayabilir.

`mem.agentandbot.com`, Cerebras Knowledge Base mimarisinden ilham alarak **üçlü hibrit skorlama (Reciprocal Rank Fusion - RRF, k=60)** kullanır:

```
                      Gelen Arama Sorgusu ("executor model nedir?")
                                     │
         ┌───────────────────────────┴───────────────────────────┐
         ▼                                                       ▼
┌─────────────────────────────────┐             ┌─────────────────────────────────┐
│      1. Vektör Arama (Cosine)   │             │    2. Tam Metin Arama (FTS)     │
│   PostgreSQL pgvector (<=>)     │             │  tsvector + plainto_tsquery     │
│   Lokal 384-dim Embedding      │             │  PostgreSQL Türkçe/Basit GIN    │
└────────────────┬────────────────┘             └────────────────┬────────────────┘
                 │                                               │
                 └───────────────────────┬───────────────────────┘
                                         ▼
                        ┌─────────────────────────────────┐
                        │   3. Zaman Aşımı Çarpanı        │
                        │      (Recency Decay e^(-t/30))  │
                        └────────────────┬────────────────┘
                                         ▼
                        ┌─────────────────────────────────┐
                        │       RRF FUSION (k=60)         │
                        │    Score = Σ 1 / (60 + Rank)    │
                        └────────────────┬────────────────┘
                                         ▼
                             En Yüksek Alakalı Sonuçlar
```

### RRF Formülü
Her bir doküman için iki arama yönteminin sıra derecesi (rank) birleştirilir:

$$\text{RRF Score} = \frac{1}{60 + \text{Rank}_{\text{vector}}} + \frac{1}{60 + \text{Rank}_{\text{fts}}} \times e^{-\frac{\text{gün}}{30}}$$

Bu sayede hem anlamsal olarak en yakın dokümanlar hem de tam kelime eşleşmesi içeren taze kayıtlar en üst sıraya yerleşir.

---

## ⚡ Sıfır Bulut Bağımlılığı: Lokal Embedding Motoru

Dış API'lere (OpenAI, Voyage vb.) her embedding sorgusunda bağımlı kalmak; hem gecikme (latency), hem maliyet, hem de ağ kesintilerinde hafızanın çökmesi anlamına gelir.

`mem.agentandbot.com`, sunucu üzerinde izole bir Docker container içinde koşan **Python `sentence-transformers/all-MiniLM-L6-v2`** microservice'ine (`mem-embed`) sahiptir:
- **Boyut:** 384-boyutlu float32 vektörler
- **Hafıza Tüketimi:** ~564 MB RAM
- **Hız:** Arama başına ortalama **71 ms**, ardışık ingest için saniyede **7.1 chunk**
- **Depolama:** Chunk başına sadece ~1.5 KB vektör alanı

```bash
# Canlı Sağlık Kontrolü Çıktısı (GET /health)
{
  "status": "ok",
  "version": "0.1.0",
  "stats": {
    "credentials": 2,
    "chunks": 66
  },
  "embedder": {
    "adapter": "Elixir.Mem.Memory.LocalEmbedder",
    "configured": true,
    "dimensions": 384,
    "model": "sentence-transformers/all-MiniLM-L6-v2"
  }
}
```

---

## 🔌 Model Context Protocol (MCP) Desteği

AI ajanlarının (Claude Code, Hermes, OpenCode, Codex vb.) hafızaya doğrudan erişebilmesi için `mem.agentandbot.com`, resmi **Model Context Protocol (JSON-RPC 2.0 / Streamable HTTP)** standartlarını tam olarak destekler.

### MCP Endpoint: `POST https://mem.agentandbot.com/mcp`

Sunulan standart araçlar (Tools):
1. `memory_search` — Proje ve kaynak filtreleriyle semantik + tam metin hibrit arama.
2. `memory_add` — Yeni bir bilgi parçasını, etiketleri ve metaverisiyle birlikte hafızaya indeksleme.
3. `memory_health` — Vektör motoru ve kayıt istatistiklerini izleme.

```json
// Örnek: Hermes Ajanı memory_search Tool Çağrısı
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "memory_search",
    "arguments": {
      "query": "Universal Executor modeli nedir?",
      "project": "agentandbot",
      "limit": 3
    }
  },
  "id": 1
}
```

---

## 🤖 Çoklu Ajan Konseyi ve Ortak Hafıza İşbirliği

AgentAndBot ekosisteminde birden fazla uzman ajan görev yapar:
- **Hermes Agent:** Orkestrasyon, planlama, sistem yönetimi ve kullanıcı koordinasyonu.
- **Sara:** Güvenlik denetimi, kod incelemesi ve audit.
- **OpenCode:** Mimari geliştirme, frontend/backend kod üretimi.

Ajanlar arasındaki işbirliği hafıza servisi üzerinden şöyle akar:

```
[Kullanıcı / Görev Talebi]
          │
          ▼
┌──────────────────┐       1. Hafıza Sorgusu ("Benzer iş yapıldı mı?")
│   Hermes Agent   │ ──────────────────────────────────────────────┐
└─────────┬────────┘                                               │
          │ 2. Delege et                                           ▼
          ▼                                            ┌───────────────────────┐
┌──────────────────┐                                   │   mem.agentandbot.com │
│  OpenCode / Sara │ ───────────────────────────────── │    Ortak Bilgi Üssü   │
└─────────┬────────┘ 3. Karar & Çıktıyı (Artifact) Kaydet └───────────────────────┘
          │                                                        ▲
          └────────────────────────────────────────────────────────┘
```

Bir ajan bir hatayı çözdüğünde (örneğin *"Elixir LiveView guard clause runtime list pitfall"*), bunu `mem`'e kaydeder. Bir sonraki hafta başka bir ajan aynı hatayla karşılaştığında arama yaparak çözümü saniyeler içinde uygular.

---

## 🌐 Otomatik Veri Toplayıcılar (Connector Ailesi)

Kurumsal bilginin hafızaya akması için Python tabanlı plug-and-play connector mimarisi devrededir:

| Connector | Kaynak | Açıklama |
|---|---|---|
| `github_connector.py` | GitHub Repoları | Markdown dokümanlarını, mimari şemalarını çeker. |
| `folder_connector.py` | Lokal Dizinler | Belirlenen klasörlerdeki `.md`, `.ex`, `.txt` dosyalarını indeksler. |
| `website_connector.py` | Web Siteleri & Blog | Sitemap üzerinden yayınlanan makaleleri hafızaya yazar. |
| `aab_rooms_sync.py` | AAB Sohbet Odaları | Ajanların odalarda vardığı önemli sentezleri hafızaya aktarır. |
| `qm_mem_sync.py` | Quartermaster | Takım notebook'larını gizlilik filtrelerine uyarak senkronize eder. |

---

## 🚀 Sonuç: Kalıcı Akıl, Güvenilir Ajanlar

Yapay zeka modelleri ne kadar güçlü olursa olsun, **kalıcı ve güvenilir bir hafıza katmanı olmadan gerçek bir çalışma arkadaşına dönüşemezler**.

`mem.agentandbot.com`, AgentAndBot platformunun yalnızca geçici komutlar çalıştıran bir araç değil; öğrenen, hatırlayan ve her geçen gün daha yetkin hale gelen yaşayan bir **Ajan İşletim Sistemi** olmasının temel taşıdır.

---

### Bağlantılar & Kaynaklar
- 🌐 **Canlı Hafıza Servisi:** [https://mem.agentandbot.com](https://mem.agentandbot.com)
- ⚡ **AgentAndBot Platformu:** [https://agentandbot.com](https://agentandbot.com)
- 📋 **Canlı Görev & Problem Panosu:** [https://agentandbot.com/kanban](https://agentandbot.com/kanban)
- 🐙 **GitHub:** [agentandbot-design/mem_service](https://github.com/agentandbot-design/mem_service)
