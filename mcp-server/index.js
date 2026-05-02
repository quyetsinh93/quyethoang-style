import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import Database from "better-sqlite3";
import { createServer } from "http";
import { z } from "zod";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DB_PATH = process.env.DB_PATH || path.join(__dirname, "../brain.db");
const PORT = parseInt(process.env.MCP_PORT || "3100");

// ─── DB helper ────────────────────────────────────────────────────────────────
function getDb() {
  return new Database(DB_PATH, { readonly: true });
}

function formatVND(amount) {
  return new Intl.NumberFormat("vi-VN").format(amount) + "đ";
}

function timeAgo(dateStr) {
  const diff = (Date.now() - new Date(dateStr).getTime()) / 1000;
  if (diff < 3600) return `${Math.round(diff / 60)} phút trước`;
  if (diff < 86400) return `${Math.round(diff / 3600)} giờ trước`;
  return `${Math.round(diff / 86400)} ngày trước`;
}

// ─── MCP Server setup ─────────────────────────────────────────────────────────
const server = new McpServer({
  name: "website-tools",
  version: "1.0.0",
});

// ──────────────────────────────────────────────────────────────────────────────
// Tool 1: get_daily_summary
// ──────────────────────────────────────────────────────────────────────────────
server.tool(
  "get_daily_summary",
  "Lấy báo cáo tổng hợp hoạt động kinh doanh. Dùng khi hỏi 'hôm nay thế nào', 'báo cáo', 'doanh thu', 'summary', 'report'.",
  { days: z.number().int().min(1).max(30).default(1).describe("Số ngày cần báo cáo, mặc định 1 ngày (24h qua)") },
  async ({ days }) => {
    const db = getDb();
    const since = new Date(Date.now() - days * 86400 * 1000)
      .toISOString()
      .replace("T", " ")
      .slice(0, 19);

    // Leads mới
    const leads = db
      .prepare(`SELECT name, phone, created_at FROM customers WHERE created_at >= ? ORDER BY created_at DESC LIMIT 5`)
      .all(since);

    // Đơn hàng
    const orders = db
      .prepare(
        `SELECT o.status, COUNT(*) as count, SUM(o.amount) as total
         FROM orders o WHERE o.created_at >= ?
         GROUP BY o.status`
      )
      .all(since);

    const pendingCount = orders.find((r) => r.status === "pending")?.count || 0;
    const successCount = orders.find((r) => r.status === "success")?.count || 0;
    const revenue = orders.find((r) => r.status === "success")?.total || 0;

    db.close();

    const label = days === 1 ? "hôm nay (24h qua)" : `${days} ngày qua`;
    let msg = `📊 Báo cáo ${label}:\n\n`;
    msg += `👤 Lead mới: ${leads.length}\n`;
    if (leads.length > 0) {
      leads.slice(0, 3).forEach((l) => {
        msg += `   • ${l.name} | ${l.phone} (${timeAgo(l.created_at)})\n`;
      });
    }
    msg += `\n⏳ Đơn chờ TT: ${pendingCount} đơn\n`;
    msg += `✅ Đơn thành công: ${successCount} đơn\n`;
    msg += `💰 Doanh thu: ${formatVND(revenue)}\n`;

    return { content: [{ type: "text", text: msg }] };
  }
);

// ──────────────────────────────────────────────────────────────────────────────
// Tool 2: confirm_payment
// ──────────────────────────────────────────────────────────────────────────────
server.tool(
  "confirm_payment",
  "Xác nhận thanh toán cho một đơn hàng. Dùng khi: 'xác nhận DH...', 'confirm DH...', 'đã nhận tiền', 'ok đơn', 'done DH...'. Nhận order_code (VD: DH21091234) hoặc phone khách hàng.",
  {
    order_code: z.string().optional().describe("Mã đơn hàng, VD: DH21091234"),
    phone: z.string().optional().describe("Số điện thoại khách, dùng khi không có order_code"),
  },
  async ({ order_code, phone }) => {
    const db = new Database(DB_PATH); // cần write access

    let order = null;

    if (order_code) {
      order = db
        .prepare(
          `SELECT o.id, o.order_code, o.amount, o.status, o.product_id,
                  c.name as customer_name, c.email as customer_email,
                  p.name as product_name
           FROM orders o
           LEFT JOIN customers c ON o.customer_id = c.id
           LEFT JOIN products p ON o.product_id = p.id
           WHERE o.order_code = ? LIMIT 1`
        )
        .get(order_code);
    } else if (phone) {
      order = db
        .prepare(
          `SELECT o.id, o.order_code, o.amount, o.status,
                  c.name as customer_name, c.email as customer_email,
                  p.name as product_name
           FROM orders o
           LEFT JOIN customers c ON o.customer_id = c.id
           LEFT JOIN products p ON o.product_id = p.id
           WHERE c.phone = ? AND o.status = 'pending'
           ORDER BY o.created_at DESC LIMIT 1`
        )
        .get(phone);
    }

    if (!order) {
      db.close();
      return {
        content: [{ type: "text", text: `❌ Không tìm thấy đơn hàng${order_code ? ` với mã ${order_code}` : phone ? ` của SĐT ${phone}` : ""}.` }],
      };
    }

    if (order.status === "success") {
      db.close();
      return {
        content: [{
          type: "text",
          text: `ℹ️ Đơn ${order.order_code} đã được xác nhận trước đó rồi.\n👤 ${order.customer_name} | 📦 ${order.product_name} | 💰 ${formatVND(order.amount)}`,
        }],
      };
    }

    // Cập nhật status -> success
    db.prepare(`UPDATE orders SET status = 'success' WHERE id = ?`).run(order.id);
    db.close();

    let msg = `✅ Xác nhận thanh toán thành công!\n\n`;
    msg += `📋 Mã đơn: ${order.order_code}\n`;
    msg += `👤 Khách: ${order.customer_name}\n`;
    msg += `📦 Sản phẩm: ${order.product_name}\n`;
    msg += `💰 Số tiền: ${formatVND(order.amount)}\n`;
    if (order.customer_email) {
      msg += `📧 Email: ${order.customer_email}\n`;
      msg += `\n💡 Lưu ý: Email xác nhận tự động được gửi qua webhook SePay. Nếu muốn gửi thủ công, báo tôi biết.`;
    } else {
      msg += `\n⚠️ Khách chưa có email — không gửi được email xác nhận.`;
    }

    return { content: [{ type: "text", text: msg }] };
  }
);

// ──────────────────────────────────────────────────────────────────────────────
// Tool 3: get_pending_orders
// ──────────────────────────────────────────────────────────────────────────────
server.tool(
  "get_pending_orders",
  "Xem danh sách đơn hàng chưa thanh toán (status=pending). Dùng khi: 'đơn chờ thanh toán', 'ai chưa trả tiền', 'pending orders', 'đơn pending', 'còn đơn nào chưa trả không'.",
  { limit: z.number().int().min(1).max(20).default(10).describe("Số đơn tối đa cần lấy") },
  async ({ limit }) => {
    const db = getDb();

    const rows = db
      .prepare(
        `SELECT o.id, o.order_code, o.amount, o.created_at,
                c.name as customer_name, c.phone as customer_phone,
                p.name as product_name
         FROM orders o
         LEFT JOIN customers c ON o.customer_id = c.id
         LEFT JOIN products p ON o.product_id = p.id
         WHERE o.status = 'pending'
         ORDER BY o.created_at DESC
         LIMIT ?`
      )
      .all(limit);

    db.close();

    if (rows.length === 0) {
      return { content: [{ type: "text", text: "🎉 Không có đơn hàng nào đang chờ thanh toán!" }] };
    }

    let msg = `⏳ ${rows.length} đơn chưa thanh toán:\n\n`;
    rows.forEach((r, i) => {
      msg += `${i + 1}. ${r.order_code || `#${r.id}`}\n`;
      msg += `   👤 ${r.customer_name} | 📞 ${r.customer_phone}\n`;
      msg += `   📦 ${r.product_name} | 💰 ${formatVND(r.amount)}\n`;
      msg += `   🕐 ${timeAgo(r.created_at)}\n\n`;
    });
    msg += `💡 Dùng lệnh "xác nhận [mã đơn]" để confirm thanh toán thủ công.`;

    return { content: [{ type: "text", text: msg }] };
  }
);

// ─── HTTP Server ──────────────────────────────────────────────────────────────
const httpServer = createServer(async (req, res) => {
  if (req.url === "/health" && req.method === "GET") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok", tools: 3 }));
    return;
  }

  if (req.url === "/mcp" || req.url?.startsWith("/mcp")) {
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined, // stateless
    });
    res.on("close", () => transport.close());
    await server.connect(transport);
    await transport.handleRequest(req, res);
    return;
  }

  res.writeHead(404);
  res.end("Not found");
});

httpServer.listen(PORT, "127.0.0.1", () => {
  console.log(`[MCP] Website MCP Server running at http://127.0.0.1:${PORT}/mcp`);
  console.log(`[MCP] Health check: http://127.0.0.1:${PORT}/health`);
  console.log(`[MCP] Tools: get_daily_summary, confirm_payment, get_pending_orders`);
  console.log(`[MCP] DB: ${DB_PATH}`);
});
