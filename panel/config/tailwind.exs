%{
  # For production builds, we want to minify the CSS.
  args: ~w(
    --input=css/app.css
    --output=../priv/static/assets/app.css
    --minify
  ),
  cd: Path.expand("../assets", __DIR__)
}
