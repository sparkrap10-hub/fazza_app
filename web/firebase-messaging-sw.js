importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyBoEhqJAuNXavTPGxXoppv0S0QTrtNayEI",
  authDomain: "fazzaapp-5d93c.firebaseapp.com",
  projectId: "fazzaapp-5d93c",
  storageBucket: "fazzaapp-5d93c.firebasestorage.app",
  messagingSenderId: "42446955304",
  appId: "1:42446955304:web:05ca65ca2ca76752e9261d"
});

const messaging = firebase.messaging();