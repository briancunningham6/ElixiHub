// Shell terminal hooks for better interaction
export const ShellInput = {
  mounted() {
    this.el.focus()
    this.suggestions = []
    this.showingAutocomplete = false
    
    // Common Elixir functions and modules for autocomplete
    this.commonSuggestions = [
      "IO.puts", "IO.inspect", "Enum.map", "Enum.filter", "Enum.reduce",
      "String.split", "String.replace", "String.contains?", "String.length",
      "Process.list", "Process.info", "Application.started_applications",
      "System.version", "System.get_env", ":erlang.nodes", ":observer.start",
      "GenServer.call", "GenServer.cast", "Supervisor.which_children",
      "Agent.start_link", "Agent.get", "Agent.update"
    ]
    
    // Handle keyboard shortcuts
    this.el.addEventListener("keydown", (e) => {
      switch(e.key) {
        case "ArrowUp":
          e.preventDefault()
          this.pushEvent("history_up", {})
          break
          
        case "ArrowDown":
          e.preventDefault()
          this.pushEvent("history_down", {})
          break
          
        case "Tab":
          e.preventDefault()
          this.handleAutocomplete()
          break
          
        case "l":
          if (e.ctrlKey) {
            e.preventDefault()
            this.pushEvent("clear_terminal", {})
          }
          break
          
        case "c":
          if (e.ctrlKey) {
            e.preventDefault()
            // Could implement interrupt functionality here
            console.log("Ctrl+C pressed - interrupt signal")
          }
          break
          
        case "d":
          if (e.ctrlKey) {
            e.preventDefault()
            // EOF signal - could close session
            console.log("Ctrl+D pressed - EOF signal")
          }
          break
      }
    })
    
    // Handle input changes
    this.el.addEventListener("input", (e) => {
      this.pushEvent("update_input", {value: e.target.value})
      this.updateAutocomplete(e.target.value)
    })
    
    // Auto-scroll terminal output
    this.scrollToBottom()
  },
  
  updated() {
    // Keep focus on input and scroll to bottom on updates
    this.el.focus()
    this.scrollToBottom()
  },
  
  handleAutocomplete() {
    const currentValue = this.el.value
    const cursorPos = this.el.selectionStart
    
    // Find the word at cursor position
    const beforeCursor = currentValue.substring(0, cursorPos)
    const afterCursor = currentValue.substring(cursorPos)
    
    // Simple word boundary detection
    const wordMatch = beforeCursor.match(/([A-Za-z_:][A-Za-z0-9_.:]*)?$/)
    
    if (wordMatch && wordMatch[1]) {
      const partialWord = wordMatch[1]
      const suggestions = this.commonSuggestions.filter(s => 
        s.toLowerCase().startsWith(partialWord.toLowerCase())
      )
      
      if (suggestions.length > 0) {
        // Use the first suggestion
        const suggestion = suggestions[0]
        const replacement = suggestion.substring(partialWord.length)
        
        const newValue = beforeCursor + replacement + afterCursor
        this.el.value = newValue
        
        // Update the LiveView
        this.pushEvent("update_input", {value: newValue})
        
        // Set cursor position after the completion
        const newCursorPos = cursorPos + replacement.length
        this.el.setSelectionRange(newCursorPos, newCursorPos)
      }
    }
  },
  
  updateAutocomplete(value) {
    // This could be enhanced to show a dropdown with suggestions
    // For now, we just prepare suggestions for tab completion
    const words = value.split(/\s+/)
    const lastWord = words[words.length - 1]
    
    if (lastWord && lastWord.length > 1) {
      this.suggestions = this.commonSuggestions.filter(s => 
        s.toLowerCase().startsWith(lastWord.toLowerCase())
      )
    } else {
      this.suggestions = []
    }
  },
  
  scrollToBottom() {
    const terminal = document.getElementById("terminal-output")
    if (terminal) {
      terminal.scrollTop = terminal.scrollHeight
    }
  }
}