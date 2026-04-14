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

// Gửi Form qua Formspree (email) - Không bị CORS, hoạt động 100%
const FORMSPREE_URL = 'https://formspree.io/f/maqayzzd';
const form = document.getElementById('consultingForm');

if (form) {
    form.addEventListener('submit', function(e) {
        e.preventDefault();

        const btnSubmit = form.querySelector('button[type="submit"]');
        const originalText = btnSubmit.innerText;

        btnSubmit.disabled = true;
        btnSubmit.innerText = "Đang gửi dữ liệu...";

        const data = {
            "Họ Tên":          document.getElementById('name').value,
            "Số Điện Thoại":   document.getElementById('phone').value,
            "Email":           document.getElementById('email').value,
            "Vấn Đề Gặp Phải": document.getElementById('message').value
        };

        fetch(FORMSPREE_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
            body: JSON.stringify(data)
        })
        .then(function(response) {
            if (response.ok) {
                alert('Tuyệt vời! Thông tin của anh em đã được ghi nhận. Tôi sẽ liên hệ trong thời gian sớm nhất!');
                form.reset();
            } else {
                alert('Có lỗi xảy ra. Vui lòng thử lại hoặc liên hệ trực tiếp qua số: 0943 293 236');
            }
        })
        .catch(function() {
            alert('Có lỗi xảy ra. Vui lòng thử lại hoặc liên hệ trực tiếp qua số: 0943 293 236');
        })
        .finally(function() {
            btnSubmit.disabled = false;
            btnSubmit.innerText = originalText;
        });
    });
}
