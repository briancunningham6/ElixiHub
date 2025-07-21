// Task Manager Application JavaScript

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
  console.log('Task Manager initialized');
  
  // Add any client-side functionality here
  initializeTaskManager();
});

function initializeTaskManager() {
  // Add task filtering functionality
  const filterButtons = document.querySelectorAll('[data-filter]');
  filterButtons.forEach(button => {
    button.addEventListener('click', function() {
      const filter = this.dataset.filter;
      filterTasks(filter);
    });
  });
  
  // Add task completion functionality
  const completeButtons = document.querySelectorAll('[data-complete]');
  completeButtons.forEach(button => {
    button.addEventListener('click', function() {
      const taskId = this.dataset.complete;
      completeTask(taskId);
    });
  });
}

function filterTasks(filter) {
  const tasks = document.querySelectorAll('.task-item');
  tasks.forEach(task => {
    const status = task.dataset.status;
    if (filter === 'all' || status === filter) {
      task.style.display = 'block';
    } else {
      task.style.display = 'none';
    }
  });
}

function completeTask(taskId) {
  // This would typically make an API call to update the task
  fetch(`/api/tasks/${taskId}/complete`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    }
  })
  .then(response => response.json())
  .then(data => {
    console.log('Task completed:', data);
    // Refresh the page or update the UI
    location.reload();
  })
  .catch(error => {
    console.error('Error completing task:', error);
  });
}

// Export functions for use in other modules
window.TaskManager = {
  filterTasks,
  completeTask
};