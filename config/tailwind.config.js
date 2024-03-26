const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  safelist: [{
    pattern: /hljs+/,
  }],
  theme: {
    hljs: {
      theme: 'base16/atelier-cave',
    },
    extend: {
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
      colors: {
        primary: {
          '50': '#ecfeff',
          '100': '#cef9ff',
          '200': '#a4f3fd',
          '300': '#65e7fb',
          '400': '#20d3f0',
          '500': '#04b6d6',
          '600': '#068eb1',
          '700': '#0d7491',
          '800': '#145e76',
          '900': '#154d64',
          '950': '#073245',
        },
        secondary: {
          '50': '#d1d1d7',
          '100': '#ccc9cf',
          '200': '#b7b5ba',
          '300': '#98949e',
          '400': '#746f7b',
          '500': '#56525b',
          '600': '#3f3d43',
          '700': '#2e2c30',
          '800': '#1a1a1f',
          '900': '#0f0f14',
          '950': '#0a0d0b',
        },
        tertiary: {
          '50': '#fef2f3',
          '400': '#fc2532',
          '600': '#dd2532',
          '700': '#c01c28',
          '800': '#9a1a23',
          '900': '#801c23',
          '950': '#450a0e',
        }
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
    require('tailwind-highlightjs'),
  ]
}
