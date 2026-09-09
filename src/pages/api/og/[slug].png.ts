/**
 * /api/og/[slug].png
 * Genera una imagen Open Graph dinámica (1200x630) por producto.
 * Tema: La cueva del Troll — fondo oscuro, verde troll, nombre + precio.
 *
 * @see https://github.com/vercel/satori
 * @see https://github.com/yisibl/resvg-js
 */

import type { APIRoute } from 'astro';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import satori from 'satori';
import { html } from 'satori-html';
import { Resvg } from '@resvg/resvg-js';
import sharp from 'sharp';
import { supabase } from '../../../lib/supabase';

export const prerender = false;

const require = createRequire(import.meta.url);

// Cargar fuentes una sola vez (Poppins, filtro alfabético latin)
const fontBold = readFileSync(
  require.resolve('@fontsource/poppins/files/poppins-latin-700-normal.woff'),
);
const fontRegular = readFileSync(
  require.resolve('@fontsource/poppins/files/poppins-latin-400-normal.woff'),
);

export const GET: APIRoute = async ({ params, url }) => {
  const { slug } = params;
  if (!slug) return new Response('Not found', { status: 404 });

  const debug = url.searchParams.get('debug') === '1';

  const { data: product } = await supabase
    .from('products')
    .select('name, price, compare_price, images, product_categories:category_id (name)')
    .eq('slug', slug)
    .eq('status', 'active')
    .maybeSingle();

  if (!product) return new Response('Not found', { status: 404 });

  const name: string = product.name;
  const image: string | null = product.images?.[0] ?? null;
  const price = `$${Number(product.price).toLocaleString('es-AR')}`;
  const oldPrice =
    product.compare_price && product.compare_price > product.price
      ? `$${Number(product.compare_price).toLocaleString('es-AR')}`
      : null;
  const category = (product.product_categories as any)?.name ?? 'La cueva del Troll';

  // Descargar la imagen del producto y usarla como data URI:
  // satori la incorpora seguro; si falla (hotlink-protection, timeout) va el fallback
  let imageDataUri: string | null = null;
  let imageFetchOk = false;
  let imageFetchError: string | null = null;
  if (image) {
    try {
      const res = await fetch(image, {
        headers: { 'User-Agent': 'Mozilla/5.0 (compatible; OGImageBot/1.0)' },
        signal: AbortSignal.timeout(8000),
      });
      imageFetchOk = res.ok;
      if (res.ok) {
        const raw = Buffer.from(await res.arrayBuffer());
        const mime = (res.headers.get('content-type') || 'image/jpeg').split(';')[0];
        if (mime === 'image/webp' || mime === 'image/avif') {
          // resvg no soporta webp/avif → transcodificar a PNG
          const png = await sharp(raw).png().toBuffer();
          imageDataUri = `data:image/png;base64,${png.toString('base64')}`;
        } else {
          imageDataUri = `data:${mime};base64,${raw.toString('base64')}`;
        }
      }
    } catch (e: any) {
      imageFetchError = e?.message ?? String(e);
    }
  }

  if (debug) {
    return new Response(
      JSON.stringify({ slug, image, imageFetchOk, imageFetchError, hasDataUri: !!imageDataUri, dataUriLength: imageDataUri?.length ?? 0 }, null, 2),
      { headers: { 'Content-Type': 'application/json' } },
    );
  }

  // satori-html: usar html() como FUNCIÓN con string completo (el template literal escapa los valores)
  const imageMarkup = imageDataUri
    ? `<img src="${imageDataUri}" width="550" height="550" style="width: 550px; height: 550px; object-fit: cover;" />`
    : `<div style="display: flex; width: 100%; height: 100%; align-items: center; justify-content: center; color: #4caf50; font-size: 64px; font-weight: 700;">TROLL</div>`;
  const oldPriceMarkup = oldPrice
    ? `<span style="color: #6b7f70; font-size: 36px; text-decoration: line-through; margin-left: 20px;">${oldPrice}</span>`
    : '';

  const markup = html(
    `<div style="display: flex; width: 1200px; height: 630px; background: #0a0f0d; padding: 40px; font-family: Poppins;">
      <div style="display: flex; width: 550px; height: 550px; border-radius: 24px; overflow: hidden; background: #14201a; flex-shrink: 0;">
        ${imageMarkup}
      </div>
      <div style="display: flex; flex-direction: column; justify-content: space-between; flex: 1; padding-left: 48px;">
        <div style="display: flex; flex-direction: column;">
          <span style="color: #ff5722; font-size: 28px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase;">${category}</span>
          <span style="color: #e8f5e9; font-size: 56px; font-weight: 700; line-height: 1.15; margin-top: 12px; overflow: hidden; text-overflow: ellipsis;">${name}</span>
        </div>
        <div style="display: flex; flex-direction: column;">
          <div style="display: flex; align-items: baseline;">
            <span style="color: #4caf50; font-size: 72px; font-weight: 700;">${price}</span>
            ${oldPriceMarkup}
          </div>
          <span style="color: #4caf50; font-size: 30px; font-weight: 700; margin-top: 16px; letter-spacing: 1px;">LA CUEVA DEL TROLL</span>
        </div>
      </div>
    </div>`,
  );

  const svg = await satori(markup as any, {
    width: 1200,
    height: 630,
    fonts: [
      { name: 'Poppins', data: fontBold, weight: 700, style: 'normal' },
      { name: 'Poppins', data: fontRegular, weight: 400, style: 'normal' },
    ],
  });

  const png = new Resvg(svg, {
    fitTo: { mode: 'width', value: 1200 },
  }).render().asPng();

  return new Response(new Uint8Array(png), {
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=86400, s-maxage=86400',
    },
  });
};
