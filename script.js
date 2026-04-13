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

// Cấu hình gửi Form về Google Sheet & Email
const scriptURL = 'https://script.google.com/macros/s/AKfycbzAferXglzXFD2ghsUdberBqk6dCCO054XIsu6YQ5EkhwfQChDYsQ2dpA3fjNEDzKISnQ/exec';
const form = document.getElementById('consultingForm');

if (form) {
    form.addEventListener('submit', e => {
        e.preventDefault();
        
        // Cảnh báo nếu chưa chèn link
        if(scriptURL.includes('<')){
            alert("Bạn cần dán Link App Script của Google vào biến scriptURL trong file script.js!");
            return;
        }

        const btnSubmit = form.querySelector('button[type="submit"]');
        const originalText = btnSubmit.innerText;
        
        btnSubmit.disabled = true;
        btnSubmit.innerText = "Đang gửi dữ liệu...";
        
        fetch(scriptURL, { 
            method: 'POST', 
            body: new FormData(form),
            mode: 'no-cors'
        })
        .then(response => {
            alert('Tuyệt vời! Thông tin của anh em đã được ghi nhận. Tôi sẽ liên hệ trong thời gian sớm nhất!');
            form.reset();
            btnSubmit.disabled = false;
            btnSubmit.innerText = originalText;
        })
        .catch(error => {
            console.error('Error!', error.message);
            alert('Có lỗi xảy ra trong quá trình gửi. Vui lòng thử lại sau!');
            btnSubmit.disabled = false;
            btnSubmit.innerText = originalText;
        });
    });
}
