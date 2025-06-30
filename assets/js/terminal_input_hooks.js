// Terminal input hooks for handling special keys
let TerminalInput = {
  mounted() {
    console.log("TerminalInput hook mounted");
    
    this.el.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        e.preventDefault();
        // Send tab completion
        this.pushEvent("shell_input", { data: '\t' });
      } else if (e.ctrlKey && e.key === 'c') {
        e.preventDefault();
        // Send Ctrl+C
        this.pushEvent("shell_input", { data: '\x03' });
        this.el.value = '';
      } else if (e.ctrlKey && e.key === 'd') {
        e.preventDefault();
        // Send Ctrl+D (EOF)
        this.pushEvent("shell_input", { data: '\x04' });
      }
    });
    
    // Handle insert_text event from quick commands
    this.handleEvent("insert_text", (payload) => {
      this.el.value = payload.text;
      this.el.focus();
    });
    
    // Auto-focus the input
    this.el.focus();
  },

  updated() {
    // Keep focus on the input when the component updates
    this.el.focus();
    // Clear the input value after command is sent
    this.el.value = '';
  }
};

export default TerminalInput;