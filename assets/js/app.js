// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Define all hooks in a single object
const Hooks = {
  SVGUploadZone: {
    mounted() {
      console.log("SVGUploadZone hook mounted on", this.el.id);
      
      // Get related elements more reliably
      const mainContainerId = this.el.id.replace('-dropzone', '');
      const fileInput = document.querySelector(`#${mainContainerId} .live-file-input`);
      const uploadButton = document.querySelector(`#${mainContainerId}-button`);
      
      console.log("Looking for file input in container:", mainContainerId);
      console.log("File input found:", fileInput ? "yes" : "no");
      console.log("Upload button found:", uploadButton ? "yes" : "no");
      
      if (!fileInput) {
        console.error(`Could not find file input in container: ${mainContainerId}`);
        // Try a different approach to find the input
        const allInputs = document.querySelectorAll('input[type="file"]');
        console.log("All file inputs on page:", allInputs.length);
        // Use the first file input if we can't find the specific one
        if (allInputs.length > 0) {
          console.log("Using first available file input as fallback");
          allInputs[0].id = `${mainContainerId}-input`;
          const fileInput = allInputs[0];
        }
      }
      
      if (uploadButton && fileInput) {
        // Add click handler for the button
        uploadButton.addEventListener('click', (e) => {
          e.preventDefault();
          console.log("Upload button clicked, triggering file input click");
          fileInput.click();
        });
      } else if (uploadButton) {
        // If we still can't find the file input, log an error when the button is clicked
        uploadButton.addEventListener('click', (e) => {
          e.preventDefault();
          console.error("Upload button clicked but could not find file input to trigger");
          // Try to find the input again at click time
          const inputs = document.querySelectorAll('input[type="file"]');
          if (inputs.length > 0) {
            console.log("Found a file input at click time, using it");
            inputs[0].click();
          }
        });
      }
      
      // The rest of the drag and drop code
      if (this.el) {
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
            dropZone.classList.add('border-blue-500', 'bg-blue-50');
          }, false);
        });
        
        ['dragleave', 'drop'].forEach(eventName => {
          dropZone.addEventListener(eventName, () => {
            dropZone.classList.remove('border-blue-500', 'bg-blue-50');
          }, false);
        });
        
        // Handle dropped files
        dropZone.addEventListener('drop', (e) => {
          console.log('File dropped');
          const files = e.dataTransfer.files;
          
          if (files.length > 0 && fileInput) {
            console.log(`Dropped ${files.length} files, first file:`, files[0].name);
            
            // Set the file to the input element
            const dataTransfer = new DataTransfer();
            dataTransfer.items.add(files[0]);
            fileInput.files = dataTransfer.files;
            
            // Trigger change event
            fileInput.dispatchEvent(new Event('change', { bubbles: true }));
          }
        });
      }
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
  },

  // Additional hooks here...
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
      const colorSwatch = this.el.querySelector('.color-swatch')?.parentElement;
      
      if (colorInput && textInput && colorSwatch) {
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

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
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
});

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"});
window.addEventListener("phx:page-loading-start", _info => topbar.show(300));
window.addEventListener("phx:page-loading-stop", _info => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// Handle icon copying events
window.addEventListener("icons-lv:copy", (event) => {
  const { text } = event.detail;
  navigator.clipboard.writeText(text).then(() => {
    console.log('Text copied to clipboard');
  });
});

// Debug helper - add to window to help debug any issues
window.debugFileInputs = function() {
  const inputs = document.querySelectorAll('input[type="file"]');
  console.log("File inputs found:", inputs.length);
  inputs.forEach((input, i) => {
    console.log(`Input ${i}:`, input.id, input);
  });
};

// Run debug when page loads
window.addEventListener('DOMContentLoaded', () => {
  console.log("DOM loaded, debugging file inputs");
  setTimeout(() => {
    window.debugFileInputs();
  }, 1000);
});