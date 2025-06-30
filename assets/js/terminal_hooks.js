// Terminal hooks for SSH shell integration
// This implements xterm.js integration for the SSH shell feature

let Terminal = {
  mounted() {
    console.log("Terminal hook mounted");
    this.terminal = null;
    this.connected = this.el.dataset.connected === "true";
    console.log("Initial connection status:", this.connected);
    
    if (this.connected) {
      this.initTerminal();
    }
    
    this.handleEvent("shell_output", (payload) => {
      console.log("Received shell output:", payload.data);
      if (this.terminal) {
        this.terminal.write(payload.data);
      }
    });
  },

  updated() {
    const newConnected = this.el.dataset.connected === "true";
    console.log("Terminal updated, new connection status:", newConnected, "old:", this.connected);
    
    if (newConnected && !this.connected) {
      // Connection established
      console.log("Establishing terminal connection");
      this.connected = true;
      this.initTerminal();
    } else if (!newConnected && this.connected) {
      // Connection lost
      console.log("Terminal connection lost");
      this.connected = false;
      this.destroyTerminal();
    }
  },

  destroyed() {
    this.destroyTerminal();
  },

  initTerminal() {
    console.log("Initializing terminal");
    // Always use simple terminal for now until we load xterm.js properly
    this.initSimpleTerminal();
    return;
    
    if (typeof window.Terminal === 'undefined') {
      // xterm.js not loaded, fall back to simple terminal
      this.initSimpleTerminal();
      return;
    }

    const terminalElement = document.getElementById('xterm-terminal');
    if (!terminalElement) return;

    this.terminal = new window.Terminal({
      cursorBlink: true,
      cursorStyle: 'block',
      fontSize: 14,
      fontFamily: 'Menlo, Monaco, "Courier New", monospace',
      theme: {
        background: '#000000',
        foreground: '#ffffff',
        cursor: '#ffffff',
        cursorAccent: '#000000',
        selection: '#3030ff',
        black: '#000000',
        red: '#e06c75',
        green: '#98c379',
        yellow: '#d19a66',
        blue: '#61afef',
        magenta: '#c678dd',
        cyan: '#56b6c2',
        white: '#abb2bf',
        brightBlack: '#5c6370',
        brightRed: '#e06c75',
        brightGreen: '#98c379',
        brightYellow: '#d19a66',
        brightBlue: '#61afef',
        brightMagenta: '#c678dd',
        brightCyan: '#56b6c2',
        brightWhite: '#ffffff'
      },
      cols: 120,
      rows: 30
    });

    this.terminal.open(terminalElement);
    
    // Handle terminal input
    this.terminal.onData((data) => {
      this.pushEvent("shell_input", { data: data });
    });

    // Handle terminal resize
    this.terminal.onResize((size) => {
      // Could send resize event to server if needed
      console.log('Terminal resized:', size);
    });

    // Focus the terminal
    this.terminal.focus();
  },

  initSimpleTerminal() {
    console.log("Initializing simple terminal");
    // Fallback terminal implementation without xterm.js
    const terminalElement = document.getElementById('xterm-terminal');
    if (!terminalElement) {
      console.log("Terminal element not found");
      return;
    }

    terminalElement.innerHTML = `
      <div class="simple-terminal p-4 font-mono text-sm h-96 overflow-y-auto bg-black text-white relative">
        <div class="terminal-output whitespace-pre-wrap break-words"></div>
        <div class="terminal-input-line flex items-center">
          <span class="prompt text-green-400">$ </span>
          <input type="text" class="terminal-input bg-transparent border-none outline-none flex-1 text-white ml-1" autocomplete="off" spellcheck="false" placeholder="Type your command...">
        </div>
      </div>
    `;

    const input = terminalElement.querySelector('.terminal-input');
    const output = terminalElement.querySelector('.terminal-output');
    const container = terminalElement.querySelector('.simple-terminal');

    this.simpleTerminal = {
      input: input,
      output: output,
      container: container,
      write: (data) => {
        // Handle terminal output with proper formatting
        const cleanData = data.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
        
        // Create a text node to preserve whitespace and special characters
        const textNode = document.createTextNode(cleanData);
        output.appendChild(textNode);
        
        // Auto-scroll to bottom
        container.scrollTop = container.scrollHeight;
      },
      focus: () => {
        input.focus();
      }
    };

    // Handle Enter key
    input.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') {
        const command = input.value + '\n';
        
        // Echo the command in the output
        this.simpleTerminal.write('$ ' + input.value + '\n');
        
        // Send to server
        this.pushEvent("shell_input", { data: command });
        input.value = '';
      }
    });

    // Handle special keys
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        e.preventDefault();
        // Send tab completion
        this.pushEvent("shell_input", { data: '\t' });
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        // Send up arrow for command history
        this.pushEvent("shell_input", { data: '\x1b[A' });
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        // Send down arrow for command history
        this.pushEvent("shell_input", { data: '\x1b[B' });
      } else if (e.ctrlKey && e.key === 'c') {
        e.preventDefault();
        // Send Ctrl+C
        this.pushEvent("shell_input", { data: '\x03' });
        input.value = '';
      }
    });

    // Auto-focus when clicking anywhere in the terminal
    container.addEventListener('click', () => {
      input.focus();
    });

    input.focus();
    this.terminal = this.simpleTerminal;
  },

  destroyTerminal() {
    if (this.terminal && this.terminal.dispose) {
      this.terminal.dispose();
    }
    this.terminal = null;
    
    const terminalElement = document.getElementById('xterm-terminal');
    if (terminalElement) {
      terminalElement.innerHTML = '';
    }
  }
};

export default Terminal;