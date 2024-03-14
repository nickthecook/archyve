const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
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
          '50': '#fff9ec',
          '100': '#fff0d3',
          '200': '#ffdea5',
          '300': '#ffc66d',
          '400': '#ffa132',
          '500': '#ff840a',
          '600': '#e66100',
          '700': '#cc4d02',
          '800': '#a13c0b',
          '900': '#82330c',
          '950': '#461704',
        }
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ]
}
