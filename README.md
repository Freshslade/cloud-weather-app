\# 🌦 Multi-Cloud Weather Tracking Website (Terraform | AWS + Azure)



In this project, I learned to deploy a \*\*multi-cloud static website\*\* across \*\*AWS (S3 + CloudFront + Route 53)\*\* and \*\*Azure (Storage Static Website)\*\* — all provisioned via \*\*Terraform\*\*. The goal was to understand how DNS, CDN, HTTPS, and failover actually fit together.



> \*\*Acknowledgment:\*\* Architecture inspired by \*Lucy Wang (Tech With Lucy)\*. I implemented it myself to internalize multi-cloud DNS routing, static hosting, CloudFront, and Terraform.



---



\## 🧭 Architecture Overview



\- \*\*AWS S3\*\* – primary static hosting  

\- \*\*CloudFront\*\* – CDN + HTTPS termination in front of S3  

\- \*\*Route 53\*\* – DNS (apex alias + www CNAME) and health checks  

\- \*\*Azure Storage Static Website\*\* – disaster-recovery fallback  

\- \*\*Terraform\*\* – IaC for both clouds (one `main.tf`)



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



\## ⚙️ Terraform Workflow (what I ran)



```bash

terraform init

terraform validate

terraform plan

terraform apply


☁️ AWS: S3 + CloudFront + Route 53

S3 static website



I created a bucket, enabled the new aws\_s3\_bucket\_website\_configuration, and uploaded files with correct content\_type.



CloudFront in front of S3



CloudFront provides HTTPS and global caching. The origin points to the S3 website endpoint.



What confused me (and how I fixed it):



S3 website endpoints only support HTTP. When CloudFront tried HTTPS → S3, I saw 504s.

✅ Set CloudFront Origin Protocol Policy = HTTP Only. Viewers still get HTTPS from CloudFront.



Route 53 DNS



I created a hosted zone and added:



A (alias) at the apex → CloudFront



CNAME for www → CloudFront

(Then pointed the registrar nameservers to Route 53’s NS records.)



🔵 Azure: Storage Static Website ($web)



For DR, I mirrored the site to Azure:



Resource Group + Storage Account (StorageV2)



Enabled Static Website (special $web container)



Uploaded index.html, CSS, JS, and assets via Terraform azurerm\_storage\_blob



What finally clicked: the static site isn’t a separate service — it’s the $web container. The public endpoint is:https://<storage-account>.z13.web.core.windows.net/
🌐 DNS Failover (conceptually)



Primary: CloudFront distribution (S3 origin)



Secondary: Azure Static Website endpoint



Health checks: Route 53 monitors endpoints and fails over if needed.



🔒 ACM Certificate Validation (why DNS won)



I tried email validation first and never received the messages (ACM uses admin@, webmaster@, etc.).

DNS validation was reliable: add ACM’s CNAME in DNS → certificate issued automatically.



🧠 “Things I Struggled With” → Short Explanations

Alias vs CNAME at the apex



Why it confused me: I tried to put a CNAME at sladesanctuary.com.



What’s correct: CNAMEs can’t live at the domain root. Use A (alias) at the apex → CloudFront. Use CNAME on subdomains (e.g., www).



CloudFront 504s



Why it confused me: I expected HTTPS to the S3 website endpoint.



What’s correct: S3 website endpoints are HTTP-only. CloudFront should talk HTTP to origin; users still get HTTPS at the edge.



DNS didn’t change



Why it confused me: I added Route 53 records but nothing changed.



What’s correct: The registrar must point to Route 53 nameservers from the hosted zone.



S3 403s



Why it confused me: Bucket had files but returned AccessDenied.



What’s correct: Public S3 website needs relaxed public access + policy, or use private S3 with CloudFront OAC (not shown here).



✅ Result (Live Checks)



After DNS propagation:



https://sladesanctuary.com → CloudFront (S3 origin)



Azure endpoint available for DR



Verified with curl and browser (padlock)









📌 Local Paths (for reference)



Project root: C:\\Users\\Slade\\multi-cloud-weather-tracker



Screenshots: ./screenshots/



