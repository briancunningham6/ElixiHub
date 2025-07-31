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

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
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

// File upload drag and drop functionality
document.addEventListener('DOMContentLoaded', function() {
  const fileUploadAreas = document.querySelectorAll('.file-upload-area');
  
  fileUploadAreas.forEach(area => {
    // Drag and drop handlers
    area.addEventListener('dragover', function(e) {
      e.preventDefault();
      area.classList.add('dragover');
    });
    
    area.addEventListener('dragleave', function(e) {
      e.preventDefault();
      area.classList.remove('dragover');
    });
    
    area.addEventListener('drop', function(e) {
      e.preventDefault();
      area.classList.remove('dragover');
      
      const files = e.dataTransfer.files;
      if (files.length > 0) {
        handleFileUpload(files[0], area);
      }
    });
  });
});

// Handle file upload
function handleFileUpload(file, uploadArea) {
  // Create a file reader to convert to base64
  const reader = new FileReader();
  
  reader.onload = function(e) {
    const base64Content = e.target.result.split(',')[1]; // Remove data:mime;base64, prefix
    
    // Send to server via LiveView or AJAX
    const formData = {
      path: file.name,
      content: base64Content,
      app_name: uploadArea.dataset.appName || 'default'
    };
    
    // You can customize this to integrate with your LiveView or send AJAX request
    console.log('File ready for upload:', formData);
  };
  
  reader.readAsDataURL(file);
}

// Utility functions for file operations
window.ElixiPath = {
  // Copy file path to clipboard
  copyPath: function(path) {
    navigator.clipboard.writeText(path).then(() => {
      // Show temporary success message
      const msg = document.createElement('div');
      msg.className = 'fixed top-4 right-4 bg-green-100 text-green-800 px-4 py-2 rounded shadow-lg z-50';
      msg.textContent = 'Path copied to clipboard!';
      document.body.appendChild(msg);
      
      setTimeout(() => {
        document.body.removeChild(msg);
      }, 2000);
    });
  },
  
  // Confirm delete action
  confirmDelete: function(filename) {
    return confirm(`Are you sure you want to delete "${filename}"? This action cannot be undone.`);
  },
  
  // Format file size
  formatFileSize: function(bytes) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  },
  
  // Format date
  formatDate: function(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
  }
};