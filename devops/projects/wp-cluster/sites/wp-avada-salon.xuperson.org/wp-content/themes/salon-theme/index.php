<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
    <meta charset="<?php bloginfo('charset'); ?>">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?php bloginfo('name'); ?> - <?php bloginfo('description'); ?></title>
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500&display=swap" rel="stylesheet">
    <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>

<!-- Header Section -->
<header class="salon-header">
    <h1><?php bloginfo('name'); ?></h1>
    <p><?php bloginfo('description'); ?></p>
</header>

<!-- Navigation -->
<nav class="salon-nav">
    <ul>
        <li><a href="<?php echo home_url(); ?>">Home</a></li>
        <li><a href="#services">Services</a></li>
        <li><a href="#about">About</a></li>
        <li><a href="#contact">Contact</a></li>
    </ul>
</nav>

<!-- Main Content -->
<main class="content">
    <?php if (have_posts()) : ?>
        <?php while (have_posts()) : the_post(); ?>
            <article>
                <h2><?php the_title(); ?></h2>
                <div class="post-content">
                    <?php the_content(); ?>
                </div>
            </article>
        <?php endwhile; ?>
    <?php else : ?>
        <!-- Default content when no posts exist -->
        <section class="welcome-section">
            <h2>Welcome to Avada Salon</h2>
            <p>Your premier destination for beauty and wellness. Experience luxury and relaxation in our state-of-the-art facility.</p>
        </section>

        <!-- Services Section -->
        <section id="services" class="services-section">
            <h2>Our Services</h2>
            <div class="service-grid">
                <div class="service-card">
                    <h3>Hair Styling</h3>
                    <p>Professional cuts, colors, and styling for all hair types. Our expert stylists stay current with the latest trends.</p>
                </div>
                <div class="service-card">
                    <h3>Facial Treatments</h3>
                    <p>Rejuvenating facials using premium products to cleanse, exfoliate, and nourish your skin.</p>
                </div>
                <div class="service-card">
                    <h3>Nail Care</h3>
                    <p>Complete manicure and pedicure services in a relaxing environment with attention to detail.</p>
                </div>
                <div class="service-card">
                    <h3>Massage Therapy</h3>
                    <p>Therapeutic massages to relieve stress and tension, promoting overall wellness and relaxation.</p>
                </div>
                <div class="service-card">
                    <h3>Bridal Packages</h3>
                    <p>Complete bridal beauty packages for your special day, including hair, makeup, and nail services.</p>
                </div>
                <div class="service-card">
                    <h3>Wellness Spa</h3>
                    <p>Full spa experience with aromatherapy, hot stone treatments, and holistic wellness services.</p>
                </div>
            </div>
        </section>

        <!-- About Section -->
        <section id="about" class="about-section">
            <h2>About Avada Salon</h2>
            <p>Located in the heart of the city, Avada Salon has been providing exceptional beauty and wellness services for over a decade. Our team of certified professionals is dedicated to helping you look and feel your best.</p>
            <p>We use only the finest products and latest techniques to ensure every visit is a luxurious experience. Book your appointment today and discover why we're the preferred choice for discerning clients.</p>
        </section>

        <!-- Contact Section -->
        <section id="contact" class="contact-section">
            <h2>Contact Us</h2>
            <p><strong>Address:</strong> 123 Beauty Street, City Center</p>
            <p><strong>Phone:</strong> (555) 123-SALON</p>
            <p><strong>Email:</strong> info@avadasalon.com</p>
            <p><strong>Hours:</strong> Mon-Sat 9AM-7PM, Sun 10AM-5PM</p>
        </section>
    <?php endif; ?>
</main>

<!-- Footer -->
<footer class="salon-footer">
    <p>&copy; <?php echo date('Y'); ?> <?php bloginfo('name'); ?>. All rights reserved.</p>
    <p>Powered by WordPress | Deployed with ArgoCD GitOps</p>
</footer>

<?php wp_footer(); ?>
</body>
</html>