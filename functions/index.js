const { onValueUpdated } = require("firebase-functions/v2/database");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const STATUS_TEXT = {
  accepted: "Ваш заказ принят",
  preparing: "Ваш заказ уже готовится",
  ready: "Ваш заказ готов к выдаче",
  completed: "Заказ отмечен как выданный",
  cancelled: "Заказ был отменён",
};

exports.sendOrderStatusPush = onValueUpdated(
  "/cafes/{cafeId}/orders/{orderId}",
  async (event) => {
    if (!event.data) {
      return;
    }

    const before = event.data.before.val();
    const after = event.data.after.val();
    if (!before || !after) {
      return;
    }

    if (before.status === after.status) {
      return;
    }

    const tokens = Array.from(
      new Set(
        (after.notificationTokens || [])
          .map((token) => String(token || "").trim())
          .filter(Boolean),
      ),
    );

    if (!tokens.length) {
      logger.info("Order status changed without notification tokens", {
        orderId: event.params.orderId,
        cafeId: event.params.cafeId,
        nextStatus: after.status,
      });
      return;
    }

    const status = String(after.status || "");
    const body = STATUS_TEXT[status] || "Статус вашего заказа обновился";

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "Taro",
        body,
      },
      data: {
        type: "order_status_changed",
        orderId: String(event.params.orderId || ""),
        cafeId: String(event.params.cafeId || ""),
        status,
      },
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    logger.info("Order status push sent", {
      orderId: event.params.orderId,
      cafeId: event.params.cafeId,
      nextStatus: status,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  },
);
