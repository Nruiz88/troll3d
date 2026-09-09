/**
 * /api/mercadopago/create-preference
 * Crea una preferencia de pago en MercadoPago
 * 
 * @see https://www.mercadopago.com.ar/developers/en/reference/preferences/_checkout_preferences/post
 */

import type { APIRoute } from 'astro';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = import.meta.env.SUPABASE_SERVICE_ROLE_KEY;

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const { items, shipping, customer_id, notes } = body;

    if (!items || items.length === 0) {
      return new Response(JSON.stringify({ error: 'No items provided' }), { status: 400 });
    }

    // Create admin client
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get MercadoPago credentials from settings
    const { data: accessTokenSetting } = await supabase
      .from('settings')
      .select('value')
      .eq('key', 'mercadopago_access_token')
      .single();

    const { data: testModeSetting } = await supabase
      .from('settings')
      .select('value')
      .eq('key', 'mercadopago_test_mode')
      .single();

    let accessToken: string;
    try {
      accessToken = typeof accessTokenSetting?.value === 'string' 
        ? JSON.parse(accessTokenSetting.value) 
        : accessTokenSetting?.value;
    } catch {
      return new Response(JSON.stringify({ 
        error: 'MercadoPago no está configurado. Ve a Configuración → Pagos.' 
      }), { status: 500 });
    }

    if (!accessToken) {
      return new Response(JSON.stringify({ 
        error: 'Access Token de MercadoPago no configurado' 
      }), { status: 500 });
    }

    // Calculate total
    const total = items.reduce((sum: number, item: any) => sum + (item.price * item.quantity), 0);

    // Create order in database first
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .insert({
        customer_id: customer_id || null,
        status: 'pending',
        payment_status: 'pending',
        subtotal: total,
        shipping_cost: 0,
        discount: 0,
        total: total,
        items: items,
        items_count: items.reduce((sum: number, item: any) => sum + item.quantity, 0),
        shipping_name: shipping?.full_name,
        shipping_address: shipping?.street_address,
        shipping_city: shipping?.city,
        shipping_state: shipping?.state,
        shipping_postal_code: shipping?.postal_code,
        shipping_country: shipping?.country,
        shipping_phone: shipping?.phone,
        notes: notes || null,
        currency: 'MXN'
      })
      .select()
      .single();

    if (orderError) {
      console.error('Order creation error:', orderError);
      return new Response(JSON.stringify({ error: 'Error creating order' }), { status: 500 });
    }

    // Create MercadoPago preference
    const preferenceItems = items.map((item: any) => ({
      title: item.name,
      unit_price: item.price,
      quantity: item.quantity,
      currency_id: 'MXN'
    }));

    const preference = {
      items: preferenceItems,
      external_reference: order.id,
      notification_url: `${new URL(request.url).origin}/api/mercadopago/webhook`,
      redirect_urls: {
        success: `${new URL(request.url).origin}/checkout/success?order=${order.id}`,
        failure: `${new URL(request.url).origin}/checkout/failure?order=${order.id}`,
        pending: `${new URL(request.url).origin}/checkout/pending?order=${order.id}`
      },
      metadata: {
        order_id: order.id,
        customer_id: customer_id
      }
    };

    const mpResponse = await fetch('https://api.mercadopago.com/checkout/preferences', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`
      },
      body: JSON.stringify(preference)
    });

    if (!mpResponse.ok) {
      const errorData = await mpResponse.json();
      console.error('MercadoPago error:', errorData);
      
      // Update order as failed
      await supabase
        .from('orders')
        .update({ status: 'cancelled', payment_status: 'failed' })
        .eq('id', order.id);

      return new Response(JSON.stringify({ 
        error: 'Error al crear la preferencia de pago',
        details: errorData.message 
      }), { status: 500 });
    }

    const preferenceData = await mpResponse.json();

    return new Response(JSON.stringify({
      id: preferenceData.id,
      init_point: preferenceData.init_point,
      sandbox_init_point: preferenceData.sandbox_init_point,
      order_id: order.id
    }), { status: 200 });

  } catch (error) {
    console.error('Create preference error:', error);
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500 });
  }
};
