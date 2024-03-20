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
      theme: 'an-old-hope',
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
          '50': '#e5e5e6',
          '100': '#d6d6d7',
          '200': '#c0c0c1',
          '300': '#9f9fa1',
          '400': '#76767a',
          '500': '#67676b',
          '600': '#4c4c4e',
          '700': '#3e3e30',
          '800': '#353436',
          '900': '#202021',
          '925': '#181819',
          '950': '#161517',
        },
        tertiary: {
          '50': '#fef2f3',
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
