// Task Manager Application JavaScript

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

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
  console.log('Task Manager initialized');
  
  // Add any client-side functionality here
  initializeTaskManager();
});

function initializeTaskManager() {
  // Custom JavaScript for task manager functionality
  
  // Handle task filtering
  const filterButtons = document.querySelectorAll('[data-filter]');
  filterButtons.forEach(button => {
    button.addEventListener('click', function() {
      const filter = this.dataset.filter;
      console.log('Filtering tasks by:', filter);
    });
  });

  // Handle task completion
  const completeButtons = document.querySelectorAll('[data-complete-task]');
  completeButtons.forEach(button => {
    button.addEventListener('click', function(e) {
      if (!confirm('Mark this task as completed?')) {
        e.preventDefault();
      }
    });
  });

  // Handle task deletion
  const deleteButtons = document.querySelectorAll('[data-delete-task]');
  deleteButtons.forEach(button => {
    button.addEventListener('click', function(e) {
      if (!confirm('Are you sure you want to delete this task?')) {
        e.preventDefault();
      }
    });
  });
}

// Add hooks for custom JavaScript behavior
window.Hooks = window.Hooks || {};

// Custom hook for auto-focus inputs in modals
window.Hooks.AutoFocus = {
  mounted() {
    this.el.focus();
  }
};

// Custom hook for handling form submissions
window.Hooks.TaskForm = {
  mounted() {
    const form = this.el;
    form.addEventListener('submit', function() {
      console.log('Task form submitted');
    });
  }
};