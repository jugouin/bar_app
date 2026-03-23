export interface OrderItem {
  productName: string;
  price: number;
  quantity: number;
}

export interface Order {
  uid: string;
  email: string;
  firstName: string;
  lastName: string;
  total: number;
  createdAt: string;
  items: OrderItem[];
}

export interface UserGroup {
  uid: string;
  email: string;
  firstName: string;
  lastName: string;
  total: number;
  orders: Order[];
  orderIds: string[];
}

export interface CheckoutResult {
  uid: string;
  email: string;
  firstName: string;
  lastName: string;
  total: number;
  checkoutId: string;
  checkoutUrl: string;
  status: "ok" | "error";
  error?: string;
}