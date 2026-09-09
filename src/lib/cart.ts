/**
 * cart.ts
 * Carrito de compras con persistencia en Supabase y localStorage.
 * Maneja estado del carrito, sincronización y operaciones CRUD.
 */

import { supabase } from './supabase';

export interface CartItem {
  id: string;
  product_id: string;
  name: string;
  slug: string;
  price: number;
  image: string | null;
  quantity: number;
}

export interface CartState {
  items: CartItem[];
  total: number;
  itemCount: number;
}

const CART_STORAGE_KEY = 'astro_cart';

// ============================================
// LocalStorage helpers
// ============================================

function getLocalCart(): CartItem[] {
  if (typeof window === 'undefined') return [];
  try {
    const stored = localStorage.getItem(CART_STORAGE_KEY);
    return stored ? JSON.parse(stored) : [];
  } catch {
    return [];
  }
}

function setLocalCart(items: CartItem[]): void {
  if (typeof window === 'undefined') return;
  localStorage.setItem(CART_STORAGE_KEY, JSON.stringify(items));
}

// ============================================
// Cart operations
// ============================================

/**
 * Obtener el estado actual del carrito
 */
export function getCartState(): CartState {
  const items = getLocalCart();
  return {
    items,
    total: items.reduce((sum, item) => sum + item.price * item.quantity, 0),
    itemCount: items.reduce((sum, item) => sum + item.quantity, 0),
  };
}

/**
 * Agregar un producto al carrito
 */
export async function addToCart(product: {
  id: string;
  name: string;
  slug: string;
  price: number;
  images?: string[];
  quantity?: number;
}): Promise<CartState> {
  const items = getLocalCart();
  const quantity = product.quantity || 1;
  const image = product.images?.[0] || null;

  const existingIndex = items.findIndex((item) => item.product_id === product.id);

  if (existingIndex >= 0) {
    items[existingIndex].quantity += quantity;
  } else {
    items.push({
      id: crypto.randomUUID(),
      product_id: product.id,
      name: product.name,
      slug: product.slug,
      price: product.price,
      image,
      quantity,
    });
  }

  setLocalCart(items);

  // Sync with Supabase if user is logged in
  await syncCartWithSupabase(items);

  return getCartState();
}

/**
 * Actualizar cantidad de un item
 */
export async function updateCartItemQuantity(
  productId: string,
  quantity: number
): Promise<CartState> {
  const items = getLocalCart();
  const index = items.findIndex((item) => item.product_id === productId);

  if (index >= 0) {
    if (quantity <= 0) {
      items.splice(index, 1);
    } else {
      items[index].quantity = quantity;
    }
  }

  setLocalCart(items);
  await syncCartWithSupabase(items);

  return getCartState();
}

/**
 * Eliminar un item del carrito
 */
export async function removeFromCart(productId: string): Promise<CartState> {
  const items = getLocalCart().filter((item) => item.product_id !== productId);
  setLocalCart(items);
  await syncCartWithSupabase(items);

  return getCartState();
}

/**
 * Vaciar el carrito
 */
export async function clearCart(): Promise<CartState> {
  setLocalCart([]);
  await syncCartWithSupabase([]);

  return getCartState();
}

/**
 * Sincronizar carrito con Supabase (si el usuario está autenticado)
 */
async function syncCartWithSupabase(items: CartItem[]): Promise<void> {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    // Get or create customer
    const { data: customer } = await supabase
      .from('customers')
      .select('id')
      .eq('id', user.id)
      .single();

    if (!customer) return;

    // Delete existing cart items
    await supabase
      .from('cart_items')
      .delete()
      .eq('customer_id', customer.id);

    // Insert new cart items
    if (items.length > 0) {
      const cartItems = items.map((item) => ({
        customer_id: customer.id,
        product_id: item.product_id,
        quantity: item.quantity,
      }));

      await supabase.from('cart_items').insert(cartItems);
    }
  } catch (error) {
    console.error('Error syncing cart with Supabase:', error);
  }
}

/**
 * Cargar carrito desde Supabase (al hacer login)
 */
export async function loadCartFromSupabase(): Promise<CartState> {
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return getCartState();

    const { data: cartItems } = await supabase
      .from('cart_items')
      .select(`
        quantity,
        products (
          id,
          name,
          slug,
          price,
          images
        )
      `)
      .eq('customer_id', user.id);

    if (cartItems && cartItems.length > 0) {
      const items: CartItem[] = cartItems.map((ci: any) => ({
        id: crypto.randomUUID(),
        product_id: ci.products.id,
        name: ci.products.name,
        slug: ci.products.slug,
        price: ci.products.price,
        image: ci.products.images?.[0] || null,
        quantity: ci.quantity,
      }));

      setLocalCart(items);
    }

    return getCartState();
  } catch (error) {
    console.error('Error loading cart from Supabase:', error);
    return getCartState();
  }
}
