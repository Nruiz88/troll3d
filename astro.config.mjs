// @ts-check
import { defineConfig } from 'astro/config';
import vercel from '@astrojs/vercel';
import sitemap from '@astrojs/sitemap';
import robotsTxt from 'astro-robots-txt';
import partytown from '@astrojs/partytown';
import compress from 'astro-compress';
import critters from 'astro-critters';
import icon from 'astro-icon';

// https://astro.build/config
export default defineConfig({
  // Sitio web (necesario para sitemap, RSS, etc.)
  site: 'https://lacuevadeltroll.com',

  // Output estático por defecto
  // Las páginas con `export const prerender = false;` se renderizan en el servidor
  // @see https://docs.astro.build/en/guides/routing/#server-ssr-mode
  output: 'static',

  // Adapter para SSR en Vercel (serverless functions para páginas con prerender = false)
  // sharp y @resvg/resvg-js funcionan en el runtime Node de Vercel (doc oficial)
  // @see https://docs.astro.build/en/guides/deploy/vercel/
  adapter: vercel(),

  // Configuración de imágenes remotas (Supabase Storage)
  // @see https://docs.astro.build/en/guides/images/#images-sources-remote-images
  image: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: '**.supabase.co',
      },
    ],
  },

  // Integraciones oficiales y community
  integrations: [
    // Genera sitemap.xml automáticamente para Google
    sitemap({
      filter: (page) =>
        !page.includes('/admin') &&
        !page.includes('/auth') &&
        !page.includes('/account') &&
        !page.includes('/api/'),
    }),

    // Genera robots.txt para controlar crawlers
    robotsTxt({
      host: 'https://lacuevadeltroll.com',
      sitemap: true,
      policy: [
        {
          userAgent: '*',
          allow: '/',
          disallow: ['/admin', '/auth', '/account', '/api/'],
        },
        {
          userAgent: 'GPTBot',
          disallow: '/',
        },
        {
          userAgent: 'CCBot',
          disallow: '/',
        },
      ],
    }),

    // Offload third-party scripts a web worker (mejora rendimiento)
    // Usar en componentes con: <script type="text/partytown" src="...">
    partytown({
      // Habilitar debug mode en desarrollo
      config: { debug: false },
    }),

    // Compresión de assets (HTML, CSS, JS, imágenes)
    compress(),

    // Inline CSS crítico automaticamente (mejora First Paint)
    critters(),

    // Iconos como componentes (<Icon name="..." />)
    icon(),
  ],

  // Configuración de Vite
  vite: {
    resolve: {
      alias: {
        '@': '/src',
      },
    },
    optimizeDeps: {
      include: ['@supabase/supabase-js'],
    },
    ssr: {
      noExternal: ['@supabase/supabase-js'],
    },
  },
});
