defmodule EAnyPanel.RolePermissionsTest do
  use EAnyPanel.DataCase, async: false

  alias EAnyPanel.Accounts

  describe "role-based tab access" do
    test "admin user can access all tabs" do
      user = user_fixture(%{role: "admin"})
      assert Accounts.can_access_tab?(user, "activity")
      assert Accounts.can_access_tab?(user, "users")
      assert Accounts.can_access_tab?(user, "secrets")
      assert Accounts.can_access_tab?(user, "dashboard")
    end

    test "viewer with empty allowed_tabs only gets dashboard" do
      user = user_fixture(%{role: "viewer", allowed_tabs: "[]"})
      assert Accounts.can_access_tab?(user, "dashboard")
      refute Accounts.can_access_tab?(user, "activity")
      refute Accounts.can_access_tab?(user, "secrets")
      assert Accounts.allowed_tabs_for(user) == []
    end

    test "viewer with explicit tabs gets only those" do
      user = user_fixture(%{role: "viewer", allowed_tabs: ~s(["activity"])})
      assert Accounts.can_access_tab?(user, "activity")
      refute Accounts.can_access_tab?(user, "users")
      refute Accounts.can_access_tab?(user, "secrets")
    end

    test "manager gets exactly its allowed tabs" do
      user = user_fixture(%{role: "manager", allowed_tabs: ~s(["activity","panel"])})
      assert Accounts.can_access_tab?(user, "activity")
      assert Accounts.can_access_tab?(user, "panel")
      refute Accounts.can_access_tab?(user, "secrets")
      refute Accounts.can_access_tab?(user, "users")
    end
  end

  describe "allowed_tabs_for" do
    test "returns explicit list when present" do
      user = user_fixture(%{role: "viewer", allowed_tabs: ~s(["panel","activity"])})
      assert Accounts.allowed_tabs_for(user) == ["panel", "activity"]
    end

    test "admin gets all tabs even with empty list" do
      user = user_fixture(%{role: "admin"})
      assert Accounts.allowed_tabs_for(user) == Accounts.all_tabs()
    end
  end

  defp user_fixture(attrs) do
    {:ok, user} =
      %EAnyPanel.Accounts.User{}
      |> Ecto.Changeset.change(
        Map.merge(
          %{
            email: "role_#{System.unique_integer([:positive])}@test.local",
            hashed_password: "$argon2id$v=19$m=65536,t=3,p=4$AAAA$BBBB",
            role: "viewer",
            allowed_tabs: "[]"
          },
          attrs
        )
      )
      |> EAnyPanel.Repo.insert()

    user
  end
end