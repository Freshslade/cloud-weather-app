\# 🌦 Multi-Cloud Weather Tracking Website (Terraform | AWS + Azure)



In this project, I learned to deploy a multi-cloud static website across AWS (S3 + CloudFront + Route 53)and Azure (Storage Static Website) — all provisioned via Terraform. The goal was to understand how DNS, CDN, HTTPS, and failover actually fit together.



> Acknowledgment: Architecture inspired by Lucy Wang (Tech With Lucy). I implemented it myself to internalize multi-cloud DNS routing, static hosting, CloudFront, and Terraform.



---



\## 🧭 Architecture Overview



AWS S3 – primary static hosting  

CloudFront – CDN + HTTPS termination in front of S3  

Route 53 – DNS (apex alias + www CNAME) and health checks  

Azure Storage Static Website – disaster-recovery fallback  

Terraform – IaC for both clouds (one `main.tf`)



!\[Project Diagram](./screenshots/project-diagram.png)



---



\## 🗂 Repository Layout

multi-cloud-weather-tracker/

├── main.tf

├── website/

│ ├── index.html

│ ├── styles.css

│ ├── script.js

│ └── assets/...

└── screenshots/

├── project-diagram.png

├── terraform-apply.png

├── cloudfront-distribution.png

├── route53-records.png

├── azure-static-website.png

├── website-live-1.png

└── website-live-2.png




---





