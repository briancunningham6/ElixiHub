// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/hello_world_app_web.ex",
    "../lib/hello_world_app_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
      }
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({addVariant}) => addVariant("phx-no-feedback", [".phx-no-feedback&", ".phx-no-feedback &"])),
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    // This plugin is optional and will gracefully skip if heroicons aren't available
    //
    (function() {
      try {
        return plugin(function({matchComponents, theme}) {
          // Try different possible locations for heroicons
          let possibleIconsDirs = [
            path.join(__dirname, "../deps/heroicons/optimized"),  // git version
            path.join(__dirname, "../deps/heroicons/priv/heroicons/optimized"),  // hex version
            path.join(__dirname, "../deps/heroicons/priv/static"),  // alternative hex structure
            path.join(__dirname, "../../deps/heroicons/optimized"),  // build-time location
            path.join(__dirname, "../../deps/heroicons/priv/heroicons/optimized")  // build-time hex
          ]
          
          let iconsDir = null
          for (let dir of possibleIconsDirs) {
            try {
              if (fs.existsSync(dir)) {
                iconsDir = dir
                break
              }
            } catch (e) {
              // Ignore access errors
            }
          }
          
          if (!iconsDir) {
            console.log("Heroicons not found - building without hero icons support")
            return
          }
          
          console.log(`Using heroicons from: ${iconsDir}`)
          
          let values = {}
          let icons = [
            ["", "/24/outline"],
            ["-solid", "/24/solid"],
            ["-mini", "/20/solid"],
            ["-micro", "/16/solid"]
          ]
          
          icons.forEach(([suffix, dir]) => {
            let fullDir = path.join(iconsDir, dir)
            try {
              if (fs.existsSync(fullDir)) {
                fs.readdirSync(fullDir).forEach(file => {
                  if (file.endsWith('.svg')) {
                    let name = path.basename(file, ".svg") + suffix
                    values[name] = {name, fullPath: path.join(fullDir, file)}
                  }
                })
              }
            } catch (err) {
              console.warn(`Could not read icons from ${fullDir}:`, err.message)
            }
          })
          
          if (Object.keys(values).length === 0) {
            console.log("No heroicons found - building without hero icons support")
            return
          }
          
          console.log(`Loaded ${Object.keys(values).length} heroicons`)
          
          matchComponents({
            "hero": ({name, fullPath}) => {
              try {
                let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
                let size = theme("spacing.6")
                if (name.endsWith("-mini")) {
                  size = theme("spacing.5")
                } else if (name.endsWith("-micro")) {
                  size = theme("spacing.4")
                }
                return {
                  [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
                  "-webkit-mask": `var(--hero-${name})`,
                  "mask": `var(--hero-${name})`,
                  "mask-repeat": "no-repeat",
                  "background-color": "currentColor",
                  "vertical-align": "middle",
                  "display": "inline-block",
                  "width": size,
                  "height": size
                }
              } catch (err) {
                console.warn(`Could not read icon ${fullPath}:`, err.message)
                return {}
              }
            }
          }, {values})
        })
      } catch (err) {
        console.warn("Heroicons plugin failed, continuing without it:", err.message)
        return plugin(() => {}) // Return empty plugin
      }
    })()
  ]
}
