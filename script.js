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
