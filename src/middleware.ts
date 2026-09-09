/**
 * Middleware de seguridad para Astro
 * Protege rutas admin y valida autenticación
 * 
 * @see https://docs.astro.build/en/guides/middleware/
 * @see https://docs.astro.build/en/guides/routing/#server-ssr-mode
 */

import { defineMiddleware } from 'astro:middleware';
import { createClient } from '@supabase/supabase-js';

// Rutas públicas que no requieren autenticación
const PUBLIC_ROUTES = [
  '/',
  '/shop',
  '/about',
  '/contact',
  '/auth/login',
  '/auth/register',
  '/checkout/success',
  '/checkout/failure',
  '/checkout/pending'
];

// APIs públicas
const PUBLIC_API_ROUTES = [
  '/api/mercadopago/webhook',
  '/api/mercadopago/create-preference',
  '/api/og/'
];

function isPublicRoute(pathname: string): boolean {
  return PUBLIC_ROUTES.some(route => 
    pathname === route || pathname.startsWith('/product/')
  );
}

function isPublicApiRoute(pathname: string): boolean {
  return PUBLIC_API_ROUTES.some(route => pathname.startsWith(route));
}

function isStaticAsset(pathname: string): boolean {
  return pathname.match(/\.(js|css|png|jpg|jpeg|gif|svg|ico|woff|woff2|webp)$/) !== null;
}

export const onRequest = defineMiddleware(async (context, next) => {
  const { pathname } = context.url;

  // Skip middleware for static assets
  if (isStaticAsset(pathname)) {
    return next();
  }

  // Allow public routes (no auth needed)
  if (isPublicRoute(pathname)) {
    const response = await next();
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('X-Frame-Options', 'DENY');
    response.headers.set('X-XSS-Protection', '1; mode=block');
    response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
    return response;
  }

  // Allow public API routes
  if (isPublicApiRoute(pathname)) {
    return next();
  }

  // For admin routes — require auth
  if (pathname.startsWith('/admin')) {
    if (pathname === '/admin/login') {
      return next();
    }

    const sessionCookie = context.cookies.get('sb-access-token')?.value;

    if (!sessionCookie) {
      return context.redirect('/admin/login');
    }

    try {
      const supabase = createClient(
        import.meta.env.PUBLIC_SUPABASE_URL,
        import.meta.env.PUBLIC_SUPABASE_ANON_KEY
      );

      const { data: { user }, error } = await supabase.auth.getUser(sessionCookie);

      if (error || !user) {
        context.cookies.delete('sb-access-token', { path: '/' });
        return context.redirect('/admin/login');
      }

      const { data: profile } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();

      if (profile?.role !== 'admin') {
        return context.redirect('/');
      }

      context.locals.user = user;
      context.locals.isAdmin = true;
    } catch (err) {
      console.error('Auth middleware error:', err);
      return context.redirect('/admin/login');
    }
  }

  // For account routes — require auth
  if (pathname.startsWith('/account')) {
    const sessionCookie = context.cookies.get('sb-access-token')?.value;

    if (!sessionCookie) {
      return context.redirect('/auth/login');
    }

    try {
      const supabase = createClient(
        import.meta.env.PUBLIC_SUPABASE_URL,
        import.meta.env.PUBLIC_SUPABASE_ANON_KEY
      );

      const { data: { user }, error } = await supabase.auth.getUser(sessionCookie);

      if (error || !user) {
        context.cookies.delete('sb-access-token', { path: '/' });
        return context.redirect('/auth/login');
      }

      context.locals.user = user;
    } catch (err) {
      console.error('Auth middleware error:', err);
      return context.redirect('/auth/login');
    }
  }

  // For protected API routes (except webhook)
  if (pathname.startsWith('/api/') && !isPublicApiRoute(pathname)) {
    const sessionCookie = context.cookies.get('sb-access-token')?.value;
    if (!sessionCookie) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  }

  // Add security headers
  const response = await next();
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-XSS-Protection', '1; mode=block');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');

  if (import.meta.env.PROD) {
    response.headers.set(
      'Content-Security-Policy',
      "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline' https://unpkg.com; img-src 'self' data: https: blob:; font-src 'self' https://fonts.gstatic.com; connect-src 'self' https://api.mercadopago.com;"
    );
  }

  return response;
});
