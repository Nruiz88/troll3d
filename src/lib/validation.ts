/**
 * Utilidades de validación y sanitización
 * Protege contra XSS y validación de datos
 */

// Sanitizar string contra XSS
export function sanitize(input: string): string {
  return input
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g, '&#x2F;');
}

// Sanitizar HTML permitiendo tags seguros
export function sanitizeHtml(input: string): string {
  const allowedTags = ['p', 'br', 'strong', 'em', 'ul', 'ol', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'];
  return input.replace(/<[^>]*>/g, (tag) => {
    const tagName = tag.replace(/[<\/>]/g, '').toLowerCase();
    if (allowedTags.includes(tagName)) {
      return tag;
    }
    return '';
  });
}

// Validar email
export function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

// Validar teléfono (México)
export function isValidPhone(phone: string): boolean {
  const phoneRegex = /^(\+?52)?[\s-]?(\d{2}[\s-]?\d{4}[\s-]?\d{4}|\d{10})$/;
  return phoneRegex.test(phone.replace(/\s/g, ''));
}

// Validar precio
export function isValidPrice(price: string | number): boolean {
  const num = typeof price === 'string' ? parseFloat(price) : price;
  return !isNaN(num) && num >= 0 && num <= 999999.99;
}

// Validar stock
export function isValidStock(stock: string | number): boolean {
  const num = typeof stock === 'string' ? parseInt(stock) : stock;
  return !isNaN(num) && num >= 0 && Number.isInteger(num);
}

// Slugificador
export function slugify(text: string): string {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

// Validar datos de producto
export function validateProduct(data: any): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (!data.name || data.name.trim().length < 2) {
    errors.push('El nombre del producto es requerido (mínimo 2 caracteres)');
  }

  if (!data.price || !isValidPrice(data.price)) {
    errors.push('El precio debe ser un número válido mayor a 0');
  }

  if (data.stock !== undefined && !isValidStock(data.stock)) {
    errors.push('El stock debe ser un número entero positivo');
  }

  if (data.compare_price && !isValidPrice(data.compare_price)) {
    errors.push('El precio de comparación no es válido');
  }

  if (data.images && Array.isArray(data.images)) {
    if (data.images.length > 10) {
      errors.push('Máximo 10 imágenes permitidas');
    }
  }

  return { valid: errors.length === 0, errors };
}

// Validar datos de checkout
export function validateCheckout(data: any): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (!data.email || !isValidEmail(data.email)) {
    errors.push('El email no es válido');
  }

  if (!data.full_name || data.full_name.trim().length < 2) {
    errors.push('El nombre completo es requerido');
  }

  if (!data.street_address || data.street_address.trim().length < 5) {
    errors.push('La dirección es requerida');
  }

  if (!data.city || data.city.trim().length < 2) {
    errors.push('La ciudad es requerida');
  }

  if (!data.postal_code || data.postal_code.trim().length < 4) {
    errors.push('El código postal es requerido');
  }

  if (!data.country || data.country.length !== 2) {
    errors.push('Selecciona un país válido');
  }

  return { valid: errors.length === 0, errors };
}

// Validar datos de contacto
export function validateContact(data: any): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (!data.name || data.name.trim().length < 2) {
    errors.push('El nombre es requerido');
  }

  if (!data.email || !isValidEmail(data.email)) {
    errors.push('El email no es válido');
  }

  if (!data.message || data.message.trim().length < 10) {
    errors.push('El mensaje debe tener al menos 10 caracteres');
  }

  if (data.phone && !isValidPhone(data.phone)) {
    errors.push('El teléfono no es válido');
  }

  return { valid: errors.length === 0, errors };
}

// Rate limiting simple (para uso en server)
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

export function checkRateLimit(
  key: string,
  maxRequests: number = 10,
  windowMs: number = 60000
): boolean {
  const now = Date.now();
  const record = rateLimitMap.get(key);

  if (!record || now > record.resetAt) {
    rateLimitMap.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }

  if (record.count >= maxRequests) {
    return false;
  }

  record.count++;
  return true;
}

// Limpiar rate limit map periódicamente
if (typeof setInterval !== 'undefined') {
  setInterval(() => {
    const now = Date.now();
    for (const [key, record] of rateLimitMap.entries()) {
      if (now > record.resetAt) {
        rateLimitMap.delete(key);
      }
    }
  }, 60000);
}
