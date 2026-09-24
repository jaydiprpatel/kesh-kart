/*
 * Firebase Cloud Messaging service worker for customer web notifications.
 * The Firebase web configuration is public client configuration, not a
 * server credential. The Web Push VAPID public key is supplied to Flutter at
 * build time when obtaining the FCM token.
 */
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB5JDQuDNbYK4pS2ImuXK_E2htpKbIQpmM',
  authDomain: 'kesh-kart.firebaseapp.com',
  projectId: 'kesh-kart',
  storageBucket: 'kesh-kart.firebasestorage.app',
  messagingSenderId: '30729698212',
  appId: '1:30729698212:web:feba3aa616df62a750df31',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  return self.registration.showNotification(notification.title || 'KeshKart', {
    body: notification.body || 'You have an appointment update.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(self.clients.openWindow('/'));
});
