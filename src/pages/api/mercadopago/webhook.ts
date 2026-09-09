/**
 * /api/mercadopago/webhook
 * Recibe notificaciones de MercadoPago y actualiza el estado de los pedidos
 * 
 * @see https://www.mercadopago.com.ar/developers/en/docs/your-integrations/notifications/webhooks
 */

import type { APIRoute } from 'astro';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = import.meta.env.SUPABASE_SERVICE_ROLE_KEY;

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    
    console.log('Webhook received:', JSON.stringify(body));

    // Create admin client for database updates
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Extract payment information
    const { type, data } = body;

    // Only process payment notifications
    if (type === 'payment') {
      const paymentId = data?.id;
      
      if (!paymentId) {
        return new Response(JSON.stringify({ error: 'No payment ID' }), { status: 400 });
      }

      // Get access token from settings
      const { data: setting } = await supabase
        .from('settings')
        .select('value')
        .eq('key', 'mercadopago_access_token')
        .single();

      let accessToken: string;
      try {
        accessToken = typeof setting?.value === 'string' 
          ? JSON.parse(setting.value) 
          : setting?.value;
      } catch {
        return new Response(JSON.stringify({ error: 'Access token not configured' }), { status: 500 });
      }

      if (!accessToken) {
        return new Response(JSON.stringify({ error: 'Access token not configured' }), { status: 500 });
      }

      // Fetch payment details from MercadoPago
      const paymentResponse = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      });

      if (!paymentResponse.ok) {
        console.error('Failed to fetch payment from MercadoPago');
        return new Response(JSON.stringify({ error: 'Failed to fetch payment' }), { status: 500 });
      }

      const payment = await paymentResponse.json();
      console.log('Payment details:', JSON.stringify(payment));

      // Extract order ID from external_reference
      const orderId = payment.external_reference;
      
      if (!orderId) {
        console.log('No external_reference found');
        return new Response(JSON.stringify({ ok: true }), { status: 200 });
      }

      // Map MercadoPago status to our status
      const statusMap: Record<string, string> = {
        'approved': 'processing',
        'pending': 'pending',
        'authorized': 'processing',
        'in_process': 'pending',
        'in_bank_process': 'pending',
        'rejected': 'cancelled',
        'cancelled': 'cancelled',
        'refunded': 'cancelled',
        'charged_back': 'cancelled'
      };

      const paymentStatusMap: Record<string, string> = {
        'approved': 'paid',
        'pending': 'pending',
        'authorized': 'authorized',
        'in_process': 'pending',
        'rejected': 'failed',
        'cancelled': 'cancelled',
        'refunded': 'refunded',
        'charged_back': 'charged_back'
      };

      const orderStatus = statusMap[payment.status] || 'pending';
      const paymentStatus = paymentStatusMap[payment.status] || 'pending';

      // Update order in database
      const { error: updateError } = await supabase
        .from('orders')
        .update({
          status: orderStatus,
          payment_status: paymentStatus,
          payment_id: paymentId.toString(),
          payment_method: payment.payment_method_id,
          updated_at: new Date().toISOString()
        })
        .eq('id', orderId);

      if (updateError) {
        console.error('Error updating order:', updateError);
        return new Response(JSON.stringify({ error: 'Database update failed' }), { status: 500 });
      }

      console.log(`Order ${orderId} updated: status=${orderStatus}, payment=${paymentStatus}`);

      // If payment approved, reduce stock
      if (payment.status === 'approved') {
        const { data: order } = await supabase
          .from('orders')
          .select('items')
          .eq('id', orderId)
          .single();

        if (order?.items) {
          for (const item of order.items) {
            await supabase.rpc('decrement_stock', {
              product_id: item.id,
              quantity: item.quantity
            });
          }
        }
      }
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });

  } catch (error) {
    console.error('Webhook error:', error);
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500 });
  }
};

// Handle GET requests (for verification)
export const GET: APIRoute = async () => {
  return new Response(JSON.stringify({ 
    status: 'ok',
    message: 'MercadoPago webhook is active'
  }), { 
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  });
};
