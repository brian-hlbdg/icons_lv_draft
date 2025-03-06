// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Define custom hooks
const Hooks = {
  CopyToClipboard: {
    mounted() {
      this.el.addEventListener("click", () => {
        const codeElement = this.el.querySelector("code");
        if (codeElement) {
          navigator.clipboard.writeText(codeElement.textContent.trim());
          
          // Show a success message
          const originalText = this.el.querySelector(".copy-text").textContent;
          this.el.querySelector(".copy-text").textContent = "Copied!";
          
          // Reset after a delay
          setTimeout(() => {
            this.el.querySelector(".copy-text").textContent = originalText;
          }, 2000);
        }
      });
    }
  },
  
  ColorPicker: {
    mounted() {
      // Sync the color input and text input
      const colorInput = this.el.querySelector('input[type="color"]');
      const textInput = this.el.querySelector('input[type="text"]');
      const colorSwatch = this.el.querySelector('.color-swatch').parentElement;
      
      // Helper functions for color handling
      const isValidHex = (color) => /^#?([0-9A-F]{3}|[0-9A-F]{6})$/i.test(color);
      
      const formatHexColor = (color) => {
        // Handle shorthand hex (e.g., #ABC to #AABBCC)
        if (/^#?([0-9A-F]{3})$/i.test(color)) {
          const hex = color.replace('#', '');
          return `#${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}`;
        }
        // Add # if missing
        if (/^[0-9A-F]{6}$/i.test(color)) {
          return `#${color}`;
        }
        return color;
      };
      
      const updateColorDisplay = (value) => {
        // Update the color swatch display
        if (value === 'currentColor' || value === '') {
          colorSwatch.style.background = 'linear-gradient(to bottom right, #fff 0%, #000 100%)';
          colorSwatch.setAttribute('data-current-color', 'true');
        } else if (isValidHex(value)) {
          const formattedColor = formatHexColor(value);
          colorSwatch.style.backgroundColor = formattedColor;
          colorSwatch.removeAttribute('data-current-color');
        } else {
          // Try to interpret the color
          try {
            colorSwatch.style.backgroundColor = value;
            colorSwatch.removeAttribute('data-current-color');
          } catch (e) {
            // If invalid, show a default
            colorSwatch.style.background = '#cccccc';
          }
        }
      };
      
      if (colorInput && textInput) {
        // Initial setup
        updateColorDisplay(textInput.value);
        
        // When color picker changes, update text input
        colorInput.addEventListener('input', (e) => {
          const newColor = e.target.value;
          textInput.value = newColor;
          updateColorDisplay(newColor);
          
          this.pushEvent("update-color", {
            color: colorInput.getAttribute("phx-value-color"),
            value: newColor
          });
        });
        
        // When text input changes
        textInput.addEventListener('input', (e) => {
          const value = e.target.value;
          
          // Update color display right away for responsive feel
          updateColorDisplay(value);
          
          // Update color input if valid hex
          if (isValidHex(value)) {
            colorInput.value = formatHexColor(value);
          }
          
          // We don't need to push an event here - the phx-change will handle it
        });
        
        // Handle special keywords
        textInput.addEventListener('blur', () => {
          if (textInput.value.toLowerCase() === 'current' || 
              textInput.value.toLowerCase() === 'currentcolor') {
            textInput.value = 'currentColor';
            updateColorDisplay('currentColor');
          }
        });
      }
    }
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      // Preserve color input values when DOM is updated
      if (from.type === "color" && from.value !== to.value) {
        to.value = from.value;
      }
      return to;
    }
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Handle icon copying events
window.addEventListener("icons-lv:copy", (event) => {
  const { text } = event.detail;
  navigator.clipboard.writeText(text).then(() => {
    console.log('Text copied to clipboard');
  });
});