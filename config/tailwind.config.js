const defaultTheme = require("tailwindcss/defaultTheme");

module.exports = {
  content: [
    "./public/*.html",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js",
    "./app/views/**/*.{erb,haml,html,slim}",
  ],
  safelist: [
    {
      pattern: /hljs+/,
    },
  ],
  theme: {
    hljs: {
      theme: "base16/atelier-cave",
    },
    extend: {
      fontFamily: {
        sans: ["Inter var", ...defaultTheme.fontFamily.sans],
      },
      colors: {
        primary: {
          50: "#f0faff",
          100: "#e1f4fd",
          200: "#bceafb",
          300: "#80dcf9",
          400: "#3dcbf3",
          500: "#14b5e3",
          600: "#089ed1",
          700: "#07759d",
          800: "#0a6282",
          900: "#0f516b",
          950: "#0a3447",
        },
        secondary: {
          50: "#f7f7f8",
          100: "#efeef0",
          200: "#dad9de",
          300: "#a9a8b1",
          400: "#83828e",
          500: "#656473",
          600: "#4f4e5b",
          700: "#3e3d47",
          800: "#383740",
          900: "#2b2a30",
          925: "#232228",
          950: "#17161b",
        },
        tertiary: {
          50: "#fef2f3",
          400: "#fc2532",
          600: "#d5212e",
          700: "#c01c28",
          800: "#9a1a23",
          900: "#801c23",
          950: "#450a0e",
        },
        error: {
          50: "#fffbec",
          100: "#fff7d3",
          200: "#ffeca5",
          300: "#ffdc6d",
          400: "#ffc032",
          500: "#ffa90a",
          600: "#ff9200",
          700: "#cc6c02",
          800: "#a1530b",
          900: "#82450c",
          950: "#462104",
        },
        warning: {
          50: "#fbfee8",
          100: "#f5ffc2",
          200: "#f0ff89",
          300: "#f2ff62",
          400: "#f3fd12",
          500: "#ecec06",
          600: "#ccbc02",
          700: "#a38805",
          800: "#866a0d",
          900: "#725611",
          950: "#432f05",
        },
      },
      animation: {
        fade: "fadeOut 3s ease-in-out",
      },

      // that is actual animation
      keyframes: (theme) => ({
        fadeOut: {
          "0%": { opacity: 100 },
          "100%": { opacity: 0 },
        },
      }),
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/aspect-ratio"),
    require("@tailwindcss/typography"),
    require("@tailwindcss/container-queries"),
    require("tailwind-highlightjs"),
  ],
};
