// Smooth scrolling for navigation links
document.querySelectorAll('.nav-links a').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
        e.preventDefault();
        
        const targetId = this.getAttribute('href');
        const targetElement = document.querySelector(targetId);
        
        if (targetElement) {
            // Update active state
            document.querySelectorAll('.nav-links a').forEach(link => link.classList.remove('active'));
            this.classList.add('active');
            
            window.scrollTo({
                top: targetElement.offsetTop - 80,
                behavior: 'smooth'
            });
        }
    });
});

// Update active state on scroll
window.addEventListener('scroll', () => {
    // Sticky navbar effect
    const navbar = document.querySelector('.navbar');
    if (window.scrollY > 50) {
        navbar.classList.add('scrolled');
    } else {
        navbar.classList.remove('scrolled');
    }

    let current = '';
    const sections = document.querySelectorAll('section');
    
    sections.forEach(section => {
        const sectionTop = section.offsetTop;
        if (pageYOffset >= sectionTop - 100) {
            current = section.getAttribute('id');
        }
    });

    document.querySelectorAll('.nav-links a').forEach(link => {
        link.classList.remove('active');
        if (link.getAttribute('href') === `#${current}`) {
            link.classList.add('active');
        }
    });
});

// Image Comparison Slider
const sliderInput = document.getElementById('sliderInput');
const imgOverlay = document.getElementById('imgOverlay');
const sliderLine = document.getElementById('sliderLine');

if (sliderInput) {
    sliderInput.addEventListener('input', (e) => {
        const sliderValue = e.target.value;
        // Update the clip-path
        imgOverlay.style.clipPath = `polygon(0 0, ${sliderValue}% 0, ${sliderValue}% 100%, 0 100%)`;
        sliderLine.style.left = `${sliderValue}%`;
    });
}

// Gửi Form về Google Sheet & Email qua Google Apps Script (doGet)
const SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbzAferXglzXFD2ghsUdberBqk6dCCO054XIsu6YQ5EkhwfQChDYsQ2dpA3fjNEDzKISnQ/exec';
const form = document.getElementById('consultingForm');

if (form) {
    form.addEventListener('submit', function(e) {
        e.preventDefault();

        const btnSubmit = form.querySelector('button[type="submit"]');
        const originalText = btnSubmit.innerText;

        btnSubmit.disabled = true;
        btnSubmit.innerText = "Đang gửi dữ liệu...";

        const hoTen = encodeURIComponent(document.getElementById('name').value);
        const sdt   = encodeURIComponent(document.getElementById('phone').value);
        const email = encodeURIComponent(document.getElementById('email').value);
        const vanDe = encodeURIComponent(document.getElementById('message').value);

        const url = SCRIPT_URL + '?hoTen=' + hoTen + '&sdt=' + sdt + '&email=' + email + '&vanDe=' + vanDe;

        // Dùng Image Ping - GET request không bị CORS chặn
        var img = new Image();
        var done = false;

        function onDone() {
            if (done) return;
            done = true;
            alert('Tuyệt vời! Thông tin của anh em đã được ghi nhận. Tôi sẽ liên hệ trong thời gian sớm nhất!');
            form.reset();
            btnSubmit.disabled = false;
            btnSubmit.innerText = originalText;
        }

        img.onload  = onDone;
        img.onerror = onDone; // Google Script không trả về ảnh nên onerror luôn chạy - đây là bình thường
        img.src = url;

        // Fallback: nếu sau 5 giây không có phản hồi vẫn báo thành công (request đã được gửi đi)
        setTimeout(onDone, 5000);
    });
}

/* =========================================
   Chatbot Logic
   ========================================= */
const chatbotBtn = document.getElementById('chatbot-toggle');
const chatbotWidget = document.getElementById('chatbot-widget');
const chatbotClose = document.getElementById('chatbot-close');
const messagesContainer = document.getElementById('chatbot-messages');
const optionsContainer = document.getElementById('chatbot-options');

// Mở/Đóng chatbot
chatbotBtn.addEventListener('click', () => {
    chatbotWidget.classList.toggle('chatbot-hidden');
    if (!chatbotWidget.classList.contains('chatbot-hidden') && messagesContainer.children.length === 0) {
        initChat();
    }
});

chatbotClose.addEventListener('click', () => {
    chatbotWidget.classList.add('chatbot-hidden');
});

// Dữ liệu kịch bản
const chatScript = {
    greeting: "Chào anh! Tôi là Quyet Hoang. <br><br>Anh vào đây chắc đang tìm cách thay đổi hình ảnh bản thân đúng không? Kể cho tôi nghe anh đang gặp khó khăn gì — mặc đồ chưa tự tin, không biết phối, hay tủ đồ toàn đồ không mặc được?",
    menu: [
        { text: "Dịch vụ của anh là gì vậy?", next: "q1" },
        { text: "299k thì được những gì?", next: "q5" },
        { text: "Online thì tư vấn có chính xác không?", next: "q2" },
        { text: "Tôi muốn đặt lịch / Mua ngay", next: "buy", action: true }
    ],
    q1: {
        msg: "Tôi có mấy dạng tùy mức độ anh cần:<br><br>— <b>Style Audit (299k):</b> Anh gửi ảnh, tôi gửi lại video phân tích cá nhân hóa trong 48 giờ.<br>— <b>Capsule Wardrobe Template (99k):</b> Tải bộ danh sách 20 items cốt lõi.<br>— <b>Tư vấn 1:1 đầy đủ (2–3.5 triệu):</b> 3 buổi làm việc cùng nhau.<br><br>Anh đang ở giai đoạn nào?",
        options: [
            { text: "Tôi quan tâm gói 299k", next: "q5" },
            { text: "Gói tư vấn 1:1 làm những gì?", next: "q_1on1" },
            { text: "Tôi muốn đặt lịch", next: "buy", action: true },
            { text: "Quay lại", next: "menu" }
        ]
    },
    q5: {
        msg: "Thực ra 299k bằng 1 bữa ăn — nhưng giúp anh không mua sai hàng triệu đồng nữa.<br><br>Anh nhận được:<br>✔ Video phân tích 15–20 phút làm riêng cho anh<br>✔ Cụ thể đồ anh đang mặc: giữ hay bỏ, tại sao<br>✔ Danh sách 5–8 items gợi ý mua thêm kèm link<br>✔ 1 lần hỏi đáp qua Zalo.",
        options: [
            { text: "Online có chính xác không?", next: "q2" },
            { text: "Gửi ảnh kiểu gì?", next: "q3" },
            { text: "Tôi muốn đặt lịch Style Audit", next: "buy", action: true },
            { text: "Để tôi suy nghĩ thêm", next: "think" }
        ]
    },
    q2: {
        msg: "Câu hỏi hợp lý — và tôi trả lời thẳng luôn: 80% những gì tôi cần biết đều hiện ra qua ảnh. Vóc dáng, màu da, fit quần áo... tất cả đều thấy rõ.<br><br>Hơn nữa, tôi <b>hoàn tiền 100%</b> nếu anh xem xong video không thấy giá trị. Anh không mất gì cả.",
        options: [
            { text: "Gửi ảnh kiểu gì? Phải đẹp không?", next: "q3" },
            { text: "Ok, chốt. Tôi muốn đặt lịch", next: "buy", action: true },
            { text: "Quay lại", next: "menu" }
        ]
    },
    q3: {
        msg: "Không cần đẹp gì hết — ảnh selfie bình thường là được. Quan trọng là:<br>✔ Đứng thẳng, thấy rõ toàn thân<br>✔ Thấy rõ outfit đang mặc<br>✔ Ánh sáng đủ nhìn rõ màu sắc<br><br>Tôi cần thấy thực tế, không cần thấy đẹp.",
        options: [
            { text: "Vậy phân tích xong bao lâu nhận được?", next: "q4" },
            { text: "Tôi đặt lịch nhé", next: "buy", action: true },
            { text: "Quay lại", next: "menu" }
        ]
    },
    q4: {
        msg: "48 giờ kể từ khi tôi nhận đủ ảnh và thông tin từ anh. Thường thì tôi làm sớm hơn — nhưng tôi cam kết tối đa là 48 giờ.",
        options: [
            { text: "Tôi muốn đặt lịch", next: "buy", action: true },
            { text: "Để tôi suy nghĩ thêm", next: "think" }
        ]
    },
    q_1on1: {
        msg: "Gói 1:1 (2-3.5 triệu) là giải pháp toàn diện: 3 buổi làm việc, tái cấu trúc tủ đồ, tìm ra màu sắc và phong cách hợp nhất với anh. <br><br>Tuy nhiên, tôi thường khuyên anh em nên bắt đầu bằng gói Style Audit (299k) để trải nghiệm trước. Số tiền này sẽ được trừ đi nếu anh nâng cấp lên gói 1:1 sau này.",
        options: [
            { text: "Vậy tôi thử gói 299k trước", next: "buy", action: true },
            { text: "Quay lại câu hỏi", next: "menu" }
        ]
    },
    think: {
        msg: "Không sao — anh chưa cần quyết định gì ngay đâu.<br><br>Nếu anh muốn, anh có thể điền form đăng ký nhận thư giãn bên dưới để tham gia danh sách chờ. Khi nào sẵn sàng tôi liên hệ lại. Không ép mua nhé 😄",
        options: [
            { text: "📝 ĐIỀN FORM BÊN DƯỚI", next: "form", action: true },
            { text: "Quay lại menu chính", next: "menu" }
        ]
    }
};

function addMessage(text, sender) {
    const msgDiv = document.createElement('div');
    msgDiv.className = 'chat-msg ' + (sender === 'bot' ? 'chat-bot' : 'chat-user');
    msgDiv.innerHTML = text;
    messagesContainer.appendChild(msgDiv);
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
}

function showOptions(options) {
    optionsContainer.innerHTML = '';
    options.forEach(opt => {
        const btn = document.createElement('button');
        btn.className = 'chat-option-btn' + (opt.action ? ' chat-action-btn' : '');
        btn.innerHTML = opt.text;
        btn.onclick = () => handleOptionClick(opt);
        optionsContainer.appendChild(btn);
    });
}

function handleOptionClick(opt) {
    addMessage(opt.text, 'user');
    optionsContainer.innerHTML = '';
    
    // Typing effect delay
    const typingDiv = document.createElement('div');
    typingDiv.className = 'chat-msg chat-bot';
    typingDiv.innerHTML = '<i class="fas fa-ellipsis-h"></i>';
    messagesContainer.appendChild(typingDiv);
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
    
    setTimeout(() => {
        messagesContainer.removeChild(typingDiv);
        
        if (opt.next === 'buy' || opt.next === 'form') {
            const botMsg = opt.next === 'buy' ? 
                "Thôi thế này — anh thử đi. Xem video phân tích xong không thấy có giá trị, tôi hoàn tiền luôn. <br><br>Anh điền thông tin vào form dưới cùng của trang này nhé!" : 
                 "Anh điền thông tin vào form cuối trang nha. Xem xong nếu thấy có ích, mình nói chuyện tiếp cũng được.";
            addMessage(botMsg, 'bot');
            
            // Generate link to form
            optionsContainer.innerHTML = '<a href="#contact" class="chat-option-btn chat-action-btn" onclick="document.getElementById(\'chatbot-widget\').classList.add(\'chatbot-hidden\')">👉 ĐIẾN FORM TẠI ĐÂY</a>';
        } else {
            const nextNode = opt.next === 'menu' ? { msg: "Anh cần tôi giúp gì thêm không?", options: chatScript.menu } : chatScript[opt.next];
            addMessage(nextNode.msg, 'bot');
            showOptions(nextNode.options);
        }
    }, 600);
}

function initChat() {
    addMessage(chatScript.greeting, 'bot');
    showOptions(chatScript.menu);
}
