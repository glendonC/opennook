// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
  site: 'https://opennook.dev',
  integrations: [
    starlight({
      title: 'OpenNook',
      description: 'An open-source framework for building macOS notch apps.',
      logo: {
        alt: 'OpenNook',
        src: './src/assets/nook-mark.svg',
        replacesTitle: false,
      },
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/athledev-labs/opennook' },
      ],
      editLink: { baseUrl: undefined },
      lastUpdated: false,
      defaultLocale: 'en',
      customCss: ['./src/styles/custom.css'],
      components: {
        Header: './src/components/Header.astro',
        SiteTitle: './src/components/SiteTitle.astro',
        ThemeSelect: './src/components/ThemeToggle.astro',
        PageTitle: './src/components/PageTitle.astro',
      },
      head: [
        {
          tag: 'link',
          attrs: { rel: 'icon', href: '/favicon.svg', type: 'image/svg+xml' },
        },
        {
          tag: 'link',
          attrs: { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' },
        },
        {
          tag: 'link',
          attrs: { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        },
        {
          tag: 'link',
          attrs: { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        },
        {
          tag: 'link',
          attrs: {
            rel: 'stylesheet',
            href:
              'https://fonts.googleapis.com/css2?family=Geist:wght@300..700&family=Geist+Mono:wght@400;500&display=swap',
          },
        },
      ],
      sidebar: [
        {
          label: 'Start',
          items: [
            { label: 'Introduction', slug: 'start/introduction' },
            { label: 'Install', slug: 'start/install' },
            { label: 'Your first nook', slug: 'start/first-nook' },
            { label: 'Examples', slug: 'guides/examples' },
          ],
        },
        {
          label: 'Customization',
          items: [
            { label: 'Theming', slug: 'guides/theming' },
            { label: 'Surface materials', slug: 'guides/surface-materials' },
            { label: 'Layout and content insets', slug: 'guides/layout-and-insets' },
            { label: 'Settings chrome', slug: 'guides/settings-chrome' },
            { label: 'Chrome customization', slug: 'guides/chrome-customization' },
            { label: 'Displays and presentation', slug: 'guides/displays' },
          ],
        },
        {
          label: 'Components',
          items: [
            { label: 'File shelf', slug: 'guides/file-shelf' },
            { label: 'Activity queue', slug: 'guides/activity-queue' },
            { label: 'Volume glyph', slug: 'guides/volume-glyph' },
          ],
        },
        {
          label: 'Hosting',
          items: [
            { label: 'Multiple modules', slug: 'guides/multiple-modules' },
          ],
        },
        {
          label: 'Reference',
          items: [
            { label: 'API reference', slug: 'reference/api' },
            { label: 'Shipping', slug: 'guides/shipping' },
            { label: 'Troubleshooting', slug: 'reference/troubleshooting' },
          ],
        },
      ],
    }),
  ],
});
