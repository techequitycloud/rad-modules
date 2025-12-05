# RAD Platform Website

This repository contains the website for the RAD (Rapid Application Deployment) platform by TechEquity.

## Getting Started

### Prerequisites

- Docker and Docker Compose

### Running the Website Locally

1. Clone this repository
2. Navigate to the project directory
3. Run the following command:

```bash
docker-compose up
```

4. Open your browser and navigate to `http://localhost:8080`

### Building for Production

To build the Docker image for production:

```bash
docker build -t rad-website .
```

To run the production container:

```bash
docker run -p 80:80 rad-website
```

## Project Structure

- `index.html` - Homepage
- `platform.html` - Platform features page
- `solutions.html` - Solutions for different user segments
- `pricing.html` - Pricing plans
- `features.html` - Detailed feature descriptions
- `about.html` - About TechEquity
- `contact.html` - Contact information and form
- `testimonials.html` - Customer testimonials
- `css/` - Stylesheet files
- `js/` - JavaScript files
- `images/` - Images and icons

## Customization

To customize the website:

1. Modify the HTML files to update content
2. Edit `css/styles.css` to change the styling
3. Update images in the `images/` directory

## License

Copyright © 2025 TechEquity. All rights reserved.
