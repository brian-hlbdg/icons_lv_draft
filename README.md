# IconsLvDraft

# IconsLv

A comprehensive SVG icon library for Phoenix LiveView applications, with seamless integration of Heroicons.

## Features

- Collection of high-quality SVG icons organized by categories
- Integration with Heroicons library
- Easy integration with Phoenix LiveView
- Customizable colors (base, active, warning)
- Copy-to-clipboard functionality for both HTML and LiveView code
- Searchable icon gallery
- Compatible with Phoenix 1.7 and LiveView 0.20+

## Installation

Add `icons_lv_draft` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {_:icons_lv_draaft, "~> 0.1.0"}
  ]
end
```

## Setup

After installing the package, you need to include the icon component in your application.

### In Phoenix 1.7

Make the icon component available in your application by adding it to your `core_components.ex` file:

```elixir
# In lib/your_app_web/components/core_components.ex
defmodule YourAppWeb.CoreComponents do
  # ... other components
  
  # Include IconsLv icon component
  defdelegate icon(assigns), to: IconsLv.Icon
end
```

## Usage

### In LiveView Templates

```elixir
<.icon name="solid/check" />
<.icon name="outline/arrow" base_color="#333333" active_color="#0066cc" />
<.icon name="transportation/car" class="w-6 h-6" />
```

### In HTML

```html
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#333333">
  <path d="M20.285 2l-11.285 11.567-5.286-5.011-3.714 3.716 9 8.728 15-15.285z" />
</svg>
```

## Heroicons Integration

IconsLv comes with built-in support for Heroicons. All Heroicons are automatically imported and available in the following categories:

- `solid/*` - Solid style Heroicons
- `outline/*` - Outline style Heroicons

For example:

```elixir
<.icon name="solid/check" />
<.icon name="outline/arrow-right" />
```

## Available Icon Categories

- **Solid** - Filled style icons
- **Outline** - Line style icons
- **Transportation** - Vehicle and transport icons

## Customizing Icons

Icons can be customized with various attributes:

- `base_color` - The primary color of the icon (default: "currentColor")
- `active_color` - The color for active/hover states
- `warning_color` - The color for warning states
- `class` - Additional CSS classes

Example:

```elixir
<.icon 
  name="solid/exclamation" 
  base_color="#333333" 
  active_color="#0066cc" 
  warning_color="#ff0000"
  class="w-6 h-6" 
/>
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-new-icon`)
3. Add your SVG icons to the appropriate category folder
4. Commit your changes (`git commit -am 'Add new icon: feature/my-new-icon'`)
5. Push to the branch (`git push origin feature/my-new-icon`)
6. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.



To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
