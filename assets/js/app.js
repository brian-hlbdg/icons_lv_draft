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
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
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
window.addEventListener("icons-lv:copy-code", (event) => {
  const { category, name, baseColor, activeColor, warningColor } = event.detail;
  
  // In a real app, this would call an API to get the SVG code
  console.log(`Copying icon: ${category}/${name}`, { 
    baseColor, 
    activeColor, 
    warningColor 
  });
});