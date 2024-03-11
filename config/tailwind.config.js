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
          '50': '#fef2f3',
          '100': '#fee2e4',
          '200': '#fecace',
          '300': '#fca5ab',
          '400': '#f9707a',
          '500': '#f04350',
          '600': '#dd2532',
          '700': '#c01c28',
          '800': '#9a1a23',
          '900': '#801c23',
          '950': '#450a0e',
        },
        secondary: {
          '50': '#f5f6f8',
          '100': '#eceff3',
          '200': '#dde0e8',
          '300': '#c7ccda',
          '400': '#b0b4c9',
          '500': '#9b9eb9',
          '600': '#8585a6',
          '700': '#787895',
          '800': '#5e5f75',
          '900': '#4f4f60',
          '950': '#2e2e38',
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
