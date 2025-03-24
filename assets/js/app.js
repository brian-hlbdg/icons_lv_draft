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
  SVGUploadZone: SVGAnalyzerHooks.SVGUploadZone,
  SVGDownloader: SVGAnalyzerHooks.SVGDownloader,
  SVGAnalyzer: SVGAnalyzerHooks.SVGAnalyzer,

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

  Notification: {
    mounted() {
      // Get auto-close timeout
      const closeAfter = parseInt(this.el.dataset.closeAfter, 10) || 0;
      
      // Slide in the notification
      this.el.style.transform = 'translateX(0)';
      this.el.style.opacity = '1';
      
      // Auto-close if needed
      if (closeAfter > 0) {
        this.timer = setTimeout(() => {
          this.hide();
        }, closeAfter);
      }
    },
    
    hide() {
      // Slide out animation
      this.el.style.transform = 'translateX(400px)';
      this.el.style.opacity = '0';
      
      // Remove from DOM after animation
      setTimeout(() => {
        this.el.style.display = 'none';
      }, 300);
    },
    
    updated() {
      // If the element was hidden and is being shown again
      if (this.el.style.display === 'none' && this.el.style.opacity === '0') {
        this.el.style.display = '';
        
        // Force a reflow before adding the transition back
        this.el.offsetHeight;
        
        // Show the notification again
        this.el.style.transform = 'translateX(0)';
        this.el.style.opacity = '1';
        
        // Reset auto-close timer if needed
        const closeAfter = parseInt(this.el.dataset.closeAfter, 10) || 0;
        if (closeAfter > 0) {
          clearTimeout(this.timer);
          this.timer = setTimeout(() => {
            this.hide();
          }, closeAfter);
        }
      }
    },
    
    destroyed() {
      if (this.timer) {
        clearTimeout(this.timer);
      }
    }
  },

  AutoHideNotification: {
    mounted() {
      const timeout = this.el.dataset.timeout || 5000;
      if (timeout > 0) {
        this.timer = setTimeout(() => {
          this.el.style.opacity = "0";
          this.el.style.transition = "opacity 0.5s ease-out";
          
          // After fade out, hide the element
          setTimeout(() => {
            this.el.style.display = "none";
          }, 500);
        }, timeout);
      }
    },
    
    destroyed() {
      if (this.timer) {
        clearTimeout(this.timer);
      }
    }
  },

  FileInputHook: {
    mounted() {
      // Handle click events sent from the server
      window.addEventListener('phx:js-exec', (e) => {
        const { to, attr } = e.detail;
        if (to === '#file-input' && attr === 'data-click') {
          this.el.click();
        }
      });

      // Initialize by setting the proper upload listener
      this.handleFileInputChange = (event) => {
        const files = event.target.files;
        if (files.length > 0) {
          // The LiveView uploader will handle the actual upload
          // but we need to dispatch a custom event to trigger any UI updates
          this.el.dispatchEvent(new CustomEvent('files-selected', {
            bubbles: true,
            detail: { count: files.length }
          }));
        }
      };
      
      this.el.addEventListener('change', this.handleFileInputChange);
    },
    
    destroyed() {
      if (this.handleFileInputChange) {
        this.el.removeEventListener('change', this.handleFileInputChange);
      }
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

// Place this file at assets/js/svg_analyzer_hooks.js
const SVGAnalyzerHooks = {
  SVGUploadZone: {
    mounted() {
      console.log("SVGUploadZone hook mounted on", this.el.id);
      
      // Get the container ID from the dropzone ID
      const containerId = this.el.id.replace('-dropzone', '');
      
      // Find the file input and button inside the dropzone's parent container
      const fileInput = document.getElementById(`${containerId}-input`);
      const uploadButton = document.getElementById(`${containerId}-button`);
      
      if (!fileInput) {
        console.error(`Could not find file input with ID: ${containerId}-input`);
        return;
      }
      
      if (!uploadButton) {
        console.error(`Could not find upload button with ID: ${containerId}-button`);
      } else {
        // Add click handler for the button
        uploadButton.addEventListener('click', (e) => {
          e.preventDefault();
          console.log("Upload button clicked, triggering file input click");
          fileInput.click();
        });
      }
      
      // Handle drag events on the dropzone
      const dropZone = this.el;
      
      // Handle drag events
      ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        dropZone.addEventListener(eventName, (e) => {
          e.preventDefault();
          e.stopPropagation();
          console.log(`Drag event: ${eventName}`);
        }, false);
      });
      
      // Highlight drop zone when item is dragged over it
      ['dragenter', 'dragover'].forEach(eventName => {
        dropZone.addEventListener(eventName, () => {
          console.log('Highlighting dropzone');
          dropZone.classList.add('border-blue-500', 'bg-blue-50');
        }, false);
      });
      
      ['dragleave', 'drop'].forEach(eventName => {
        dropZone.addEventListener(eventName, () => {
          console.log('Removing highlight from dropzone');
          dropZone.classList.remove('border-blue-500', 'bg-blue-50');
        }, false);
      });
      
      // Handle dropped files
      dropZone.addEventListener('drop', (e) => {
        console.log('File dropped');
        const files = e.dataTransfer.files;
        
        if (files.length > 0) {
          console.log(`Dropped ${files.length} files, first file:`, files[0].name);
          
          // Set the file to the input element
          const dataTransfer = new DataTransfer();
          dataTransfer.items.add(files[0]);
          fileInput.files = dataTransfer.files;
          
          // Trigger change event
          console.log('Dispatching change event on file input');
          fileInput.dispatchEvent(new Event('change', { bubbles: true }));
        }
      });
      
      // Also log when the file input changes
      fileInput.addEventListener('change', () => {
        console.log('File input changed:', fileInput.files.length ? fileInput.files[0].name : 'No files');
      });
    }
  },
  
  SVGDownloader: {
    mounted() {
      console.log("SVGDownloader hook mounted on", this.el.id);
      
      // Listen for download events from LiveView
      this.handleEvent("download-svg", ({ content, filename }) => {
        console.log(`Downloading SVG as ${filename}`);
        
        // Create a blob from the SVG content
        const blob = new Blob([content], { type: 'image/svg+xml' });
        const url = URL.createObjectURL(blob);
        
        // Create a temporary link and trigger download
        const link = document.createElement('a');
        link.href = url;
        link.download = filename || 'standardized.svg';
        document.body.appendChild(link);
        link.click();
        
        // Clean up
        setTimeout(() => {
          URL.revokeObjectURL(url);
          document.body.removeChild(link);
        }, 100);
      });
      
      // Listen for copy events
      this.handleEvent("copy-to-clipboard", ({ content }) => {
        console.log('Copying SVG to clipboard');
        
        if (navigator.clipboard) {
          navigator.clipboard.writeText(content)
            .then(() => {
              this.showNotification('SVG copied to clipboard!', 'success');
            })
            .catch(err => {
              console.error('Failed to copy SVG:', err);
              this.showNotification('Failed to copy SVG', 'error');
            });
        } else {
          // Fallback for browsers without clipboard API
          const textarea = document.createElement('textarea');
          textarea.value = content;
          textarea.style.position = 'fixed';  // Avoid scrolling to bottom
          document.body.appendChild(textarea);
          textarea.focus();
          textarea.select();
          
          try {
            const successful = document.execCommand('copy');
            if (successful) {
              this.showNotification('SVG copied to clipboard!', 'success');
            } else {
              this.showNotification('Failed to copy SVG', 'error');
            }
          } catch (err) {
            console.error('Failed to copy SVG:', err);
            this.showNotification('Failed to copy SVG', 'error');
          }
          
          document.body.removeChild(textarea);
        }
      });
    },
    
    showNotification(message, type = 'success') {
      // Create notification element
      const notification = document.createElement('div');
      notification.className = 'fixed bottom-4 right-4 px-6 py-3 rounded-md text-white transition transform duration-300 ease-in-out translate-y-full opacity-0';
      notification.style.zIndex = '50';
      
      if (type === 'success') {
        notification.classList.add('bg-green-500');
      } else {
        notification.classList.add('bg-red-500');
      }
      
      notification.textContent = message;
      document.body.appendChild(notification);
      
      // Animate in
      setTimeout(() => {
        notification.classList.remove('translate-y-full', 'opacity-0');
      }, 10);
      
      // Animate out and remove
      setTimeout(() => {
        notification.classList.add('translate-y-full', 'opacity-0');
        setTimeout(() => {
          document.body.removeChild(notification);
        }, 300);
      }, 3000);
    }
  }
};

export default SVGAnalyzerHooks;

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