%{
  args: ~w(
    js/app.js
    --bundle
    --target=es2017
    --outdir=../priv/static/assets
    --minify
  ),
  cd: Path.expand("../assets", __DIR__)
}
