const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { createHash } = require("node:crypto");

initializeApp();

const db = getFirestore();

// ─── DM Mesaj Bildirimi ───
// Yeni DM mesajı oluşturulduğunda alıcıya push notification gönder
exports.onNewDmMessage = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const messageData = snapshot.data();
    const senderId = messageData.senderId;
    const senderName = messageData.senderName || "Kullanıcı";
    const text = messageData.text || "";
    const mediaType = messageData.mediaType;
    const conversationId = event.params.conversationId;

    // Konuşma bilgilerini al — alıcıyı bul
    const convDoc = await db.collection("conversations").doc(conversationId).get();
    if (!convDoc.exists) return;

    const convData = convDoc.data();
    const participantIds = convData.participantIds || [];

    // Alıcıyı bul (gönderen olmayan)
    const receiverId = participantIds.find((id) => id !== senderId);
    if (!receiverId) return;

    // Alıcının FCM token'ını al
    const receiverDoc = await db.collection("users").doc(receiverId).get();
    if (!receiverDoc.exists) return;

    const receiverData = receiverDoc.data();
    const fcmToken = receiverData.fcmToken;
    if (!fcmToken) return;

    // Bildirim mesajı oluştur
    let body = text;
    if (!text && mediaType) {
      switch (mediaType) {
        case "image":
          body = "📷 Fotoğraf gönderdi";
          break;
        case "video":
          body = "🎥 Video gönderdi";
          break;
        case "file":
          body = "📄 Dosya gönderdi";
          break;
        default:
          body = "Yeni bir mesaj gönderdi";
      }
    }

    const message = {
      token: fcmToken,
      notification: {
        title: senderName,
        body: body || "Yeni bir mesaj gönderdi",
      },
      data: {
        type: "dm",
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: "default",
          },
        },
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "khub_channel",
        },
      },
    };

    try {
      await getMessaging().send(message);
      console.log(`DM notification sent to ${receiverId} from ${senderName}`);
    } catch (error) {
      console.error("DM notification error:", error);
      // Token geçersizse sil
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        await db.collection("users").doc(receiverId).update({
          fcmToken: null,
        });
      }
    }
  }
);

// ─── Kampüs Sohbet Bildirimi ───
// Kampüs sohbetine yeni mesaj geldiğinde tüm kullanıcılara bildirim gönder
exports.onNewCampusMessage = onDocumentCreated(
  "messages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const messageData = snapshot.data();
    const senderId = messageData.senderId;
    const senderName = messageData.senderName || "Öğrenci";
    const text = messageData.text || "";
    const mediaType = messageData.mediaType;

    let body = text;
    if (!text && mediaType) {
      switch (mediaType) {
        case "image":
          body = "📷 Fotoğraf paylaştı";
          break;
        case "video":
          body = "🎥 Video paylaştı";
          break;
        default:
          body = "Yeni bir mesaj gönderdi";
      }
    }

    // Topic üzerinden tüm kullanıcılara gönder
    const message = {
      topic: "all_users",
      notification: {
        title: `${senderName} · Kampüs Sohbet`,
        body: body || "Yeni bir mesaj gönderdi",
      },
      data: {
        type: "campus_chat",
        senderId: senderId || "",
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: "default",
          },
        },
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "khub_channel",
        },
      },
    };

    try {
      await getMessaging().send(message);
      console.log(`Campus chat notification sent from ${senderName}`);
    } catch (error) {
      console.error("Campus chat notification error:", error);
    }
  }
);

// ─── Takip Bildirimi ───
// Yeni takip isteği/kabulu geldiğinde bildirim gönder
exports.onNewNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const type = data.type;
    const toUserId = data.toUserId;
    const fromUserName = data.fromUserName || "Kullanıcı";

    if (!toUserId) return;

    // Alıcının FCM token'ını al
    const userDoc = await db.collection("users").doc(toUserId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;
    if (!fcmToken) return;

    let title = "K-Hub";
    let body = "";

    switch (type) {
      case "follow":
        title = "Yeni Takipçi";
        body = `${fromUserName} seni takip etmeye başladı`;
        break;
      case "like":
        title = "Beğeni";
        body = `${fromUserName} paylaşımını beğendi`;
        break;
      case "comment":
        title = "Yorum";
        body = `${fromUserName} paylaşımına yorum yaptı`;
        break;
      default:
        body = `${fromUserName} ile bir etkileşiminiz var`;
    }

    const message = {
      token: fcmToken,
      notification: { title, body },
      data: {
        type: type || "notification",
        fromUserId: data.fromUserId || "",
      },
      apns: {
        payload: { aps: { badge: 1, sound: "default" } },
      },
      android: {
        priority: "high",
        notification: { sound: "default", channelId: "khub_channel" },
      },
    };

    try {
      await getMessaging().send(message);
      console.log(`${type} notification sent to ${toUserId}`);
    } catch (error) {
      console.error("Notification error:", error);
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        await db.collection("users").doc(toUserId).update({ fcmToken: null });
      }
    }
  }
);

// ─── Premium Dogrulama (Callable) ───
// Not: Bu akista magazadan gelen veri formati temel seviyede islenir.
// Uretimde server-side App Store / Play Store receipt verification eklenmelidir.
exports.verifyPremiumPurchase = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Giris yapmadan islem yapilamaz.");
  }

  const uid = request.auth.uid;
  const payload = request.data || {};
  const productId = typeof payload.productId === "string" ? payload.productId.trim() : "";
  const purchaseId = typeof payload.purchaseId === "string" ? payload.purchaseId.trim() : "";
  const transactionDate = typeof payload.transactionDate === "string" ? payload.transactionDate : "";
  const storeSource = typeof payload.storeSource === "string" ? payload.storeSource : "store_unknown";
  const purchaseStatus = typeof payload.purchaseStatus === "string" ? payload.purchaseStatus : "unknown";
  const verificationData = payload.verificationData || {};
  const serverVerificationData = typeof verificationData.serverVerificationData === "string" ?
    verificationData.serverVerificationData :
    "";
  const localVerificationData = typeof verificationData.localVerificationData === "string" ?
    verificationData.localVerificationData :
    "";

  if (!productId) {
    throw new HttpsError("invalid-argument", "productId zorunlu.");
  }

  if (productId !== "khub_premium_monthly") {
    throw new HttpsError("failed-precondition", "Desteklenmeyen urun.");
  }

  const rawReceiptFingerprint = [
    uid,
    productId,
    purchaseId,
    transactionDate,
    serverVerificationData || localVerificationData,
  ].join("|");
  const receiptHash = createHash("sha256").update(rawReceiptFingerprint).digest("hex");

  const userRef = db.collection("users").doc(uid);
  const receiptRef = db.collection("premium_receipts").doc(receiptHash);

  await db.runTransaction(async (tx) => {
    const existing = await tx.get(receiptRef);
    if (existing.exists) {
      const receiptData = existing.data() || {};
      if (receiptData.uid && receiptData.uid !== uid) {
        throw new HttpsError("permission-denied", "Bu satin alma kaydi baska hesaba ait.");
      }
    } else {
      tx.set(receiptRef, {
        uid,
        productId,
        purchaseId: purchaseId || null,
        purchaseStatus,
        storeSource,
        transactionDate: transactionDate || null,
        serverVerificationDataHash: serverVerificationData ?
          createHash("sha256").update(serverVerificationData).digest("hex") :
          null,
        localVerificationDataHash: localVerificationData ?
          createHash("sha256").update(localVerificationData).digest("hex") :
          null,
        receiptHash,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    tx.set(userRef, {
      isPremium: true,
      premiumStatus: "active",
      premiumPlan: productId,
      premiumSource: storeSource,
      premiumPurchaseId: purchaseId || null,
      premiumProductId: productId,
      premiumTransactionDate: transactionDate || null,
      premiumLastVerification: "callable_basic_check_pending_store_validation",
      premiumActivatedAt: FieldValue.serverTimestamp(),
      premiumUpdatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return {
    ok: true,
    premiumStatus: "active",
  };
});
