# Staticman Docker Swarm Deployment

This repository contains all the necessary files to deploy Staticman as a Docker Swarm service on Google Cloud Platform.

## Prerequisites

- Google Cloud Platform account
- GitHub repository for your Hugo site
- GitHub Personal Access Token

## GCP Instance Setup

### 1. Create a Compute Instance (Free Tier Compatible)

> **Note**: This setup uses Google Cloud's Always Free tier resources. The e2-micro instance provides 1 vCPU and 1 GB memory, which is sufficient for a basic Staticman deployment with light traffic.

```bash
# Set your project ID
export PROJECT_ID=your-project-id

# Create a free tier compute instance
gcloud compute instances create staticman-server \
    --project=$PROJECT_ID \
    --zone=us-east1-b \
    --machine-type=e2-micro \
    --network-tier=STANDARD \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=your-service-account@$PROJECT_ID.iam.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --tags=docker-swarm,http-server,https-server \
    --create-disk=auto-delete=yes,boot=yes,device-name=staticman-server,image=projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20240319,mode=rw,size=30,type=projects/$PROJECT_ID/zones/us-east1-b/diskTypes/pd-standard \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=environment=production,service=staticman \
    --reservation-affinity=any
```

Or create via the Console:
1. Go to [Compute Engine](https://console.cloud.google.com/compute/instances)
2. Click "Create Instance"
3. Configure:
   - **Name**: `staticman-server`
   - **Region**: `us-east1` (Always Free eligible)
   - **Zone**: `us-east1-b`
   - **Machine type**: `e2-micro` (1 vCPU, 1 GB memory) - **Always Free**
   - **Boot disk**: Ubuntu 22.04 LTS, 30 GB standard persistent disk - **Always Free**
   - **Firewall**: Allow HTTP and HTTPS traffic
   - **Network tags**: `docker-swarm`, `http-server`, `https-server`

### Free Tier Considerations

- **e2-micro**: 1 shared vCPU, 1 GB memory (Always Free)
- **30 GB standard persistent disk**: Included in Always Free tier
- **us-east1 region**: One of the Always Free eligible regions
- **Network tier**: Standard (lower cost than Premium)
- **Monthly limits**: 744 hours of e2-micro usage (enough for 24/7 operation)

### 2. Configure Firewall Rules

```bash
# Allow HTTP traffic
gcloud compute firewall-rules create allow-staticman-http \
    --allow tcp:80 \
    --source-ranges 0.0.0.0/0 \
    --target-tags http-server \
    --description "Allow HTTP traffic for Staticman"

# Allow HTTPS traffic
gcloud compute firewall-rules create allow-staticman-https \
    --allow tcp:443 \
    --source-ranges 0.0.0.0/0 \
    --target-tags https-server \
    --description "Allow HTTPS traffic for Staticman"

# Allow Docker Swarm communication (if you plan to add more nodes)
gcloud compute firewall-rules create allow-docker-swarm \
    --allow tcp:2376-2377,tcp:7946,udp:7946,udp:4789 \
    --source-tags docker-swarm \
    --target-tags docker-swarm \
    --description "Allow Docker Swarm cluster communication"
```

### 3. SSH into Your Instance

```bash
# SSH into the instance
gcloud compute ssh staticman-server --zone=us-east1-b

# Or use the SSH button in the Google Cloud Console
```

### 4. Install Docker and Docker Compose

Once connected to your instance:

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Docker using the official script
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Add your user to the docker group
sudo usermod -aG docker $USER

# Apply the group membership (logout/login or use newgrp)
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installations
docker --version
docker-compose --version

# Test Docker installation
docker run hello-world
```

### 5. Initialize Docker Swarm

```bash
# Get your instance's internal IP
INTERNAL_IP=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

# Initialize Docker Swarm
docker swarm init --advertise-addr $INTERNAL_IP

# Save the join token for future worker nodes (optional)
docker swarm join-token worker > ~/swarm-join-token.txt
```

### 6. Install Git and Basic Tools

```bash
# Install git and other useful tools
sudo apt install -y git curl wget nano htop

# Configure git (optional, for managing your deployment repo)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 7. Optional: Set Up Automatic Security Updates

```bash
# Install unattended-upgrades for automatic security updates
sudo apt install -y unattended-upgrades

# Configure automatic updates
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 8. Get Your Instance IP

```bash
# Get external IP (for accessing Staticman)
curl ifconfig.me

# Get internal IP (for Docker Swarm)
curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip
```

### 9. Optional: Set Up a Static IP

> **Note**: Static IP addresses are not included in the Always Free tier and will incur charges (~$1.46/month for an unused static IP, free while attached to a running instance).

```bash
# Reserve a static external IP
gcloud compute addresses create staticman-ip --region=us-east1

# Get the reserved IP
gcloud compute addresses describe staticman-ip --region=us-east1

# Assign the static IP to your instance
gcloud compute instances delete-access-config staticman-server --zone=us-east1-b
gcloud compute instances add-access-config staticman-server \
    --zone=us-east1-b \
    --access-config-name="External NAT" \
    --address=RESERVED_IP_ADDRESS
```

Your GCP instance is now ready for Staticman deployment!

## Performance Optimization for e2-micro

Since the e2-micro instance has limited resources (1 vCPU, 1 GB RAM), consider these optimizations:

### Reduce Docker Swarm Replicas

In `docker-compose.swarm.yml`, reduce the Staticman replicas from 2 to 1:

```yaml
deploy:
  replicas: 1  # Reduced from 2 for e2-micro
```

### Enable Swap (Optional)

Add swap space to help with memory constraints:

```bash
# Create 1GB swap file
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make swap permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Monitor Resource Usage

```bash
# Monitor CPU and memory usage
htop

# Check Docker container resource usage
docker stats
```

## Quick Start

1. **Clone this repository on your GCP instance:**
   ```bash
   git clone https://github.com/yourusername/staticman-deployment.git
   cd staticman-deployment
   ```

2. **Generate RSA keys:**
   ```bash
   chmod +x scripts/*.sh
   ./scripts/generate-keys.sh
   ```

3. **Add the public key to your GitHub repository:**
   - Go to your Hugo site repository settings
   - Navigate to "Deploy keys"
   - Add the public key with write access

4. **Configure environment:**
   ```bash
   cp .env.example .env
   nano .env  # Add your GitHub token and private key
   ```

5. **Set up and deploy:**
   ```bash
   ./scripts/setup.sh
   ./scripts/deploy.sh
   ```

## Configuration

### Environment Variables

Edit `.env` file with your values:

- `GITHUB_TOKEN`: Your GitHub Personal Access Token with repo scope
- `RSA_PRIVATE_KEY`: The private key generated by the setup script
- `DOMAIN`: (Optional) Your domain name for SSL setup
- `STACK_NAME`: Name for your Docker stack (default: staticman)

### GitHub Token Permissions

Your GitHub token needs these scopes:
- `repo` (Full repository access)
- `user:email` (Access user email)

## Usage

### Deploy/Update Stack
```bash
./scripts/deploy.sh
```

### Monitor Services
```bash
# List services
docker stack services staticman

# View logs
docker service logs staticman_staticman
docker service logs staticman_nginx

# Scale services
docker service scale staticman_staticman=3
```

### Access Staticman

Your Staticman API will be available at:
- `http://YOUR_GCP_INSTANCE_IP/v3/entry/github/USERNAME/REPO/BRANCH/comments`

### Hugo Site Configuration

In your Hugo site, update your comment form action to point to your Staticman instance:

```html
<form method="POST" action="http://YOUR_GCP_INSTANCE_IP/v3/entry/github/USERNAME/REPO/main/comments">
  <input name="options[redirect]" type="hidden" value="{{ .Permalink }}">
  <input name="options[slug]" type="hidden" value="{{ .File.ContentBaseName }}">
  <input name="fields[name]" type="text" placeholder="Name" required>
  <textarea name="fields[message]" placeholder="Comment" required></textarea>
  <button type="submit">Post Comment</button>
</form>
```

## Architecture

- **Staticman Service**: 2 replicas for high availability
- **Nginx Proxy**: Load balancer with rate limiting
- **Docker Swarm**: Orchestration and auto-healing
- **Health Checks**: Automatic service monitoring

## Troubleshooting

### Check Service Status
```bash
docker stack services staticman
docker service ps staticman_staticman --no-trunc
```

### View Detailed Logs
```bash
docker service logs --follow staticman_staticman
docker service logs --follow staticman_nginx
```

### Common Issues

1. **Service not starting**: Check environment variables in `.env`
2. **GitHub API errors**: Verify token permissions
3. **Comments not appearing**: Check repository deploy key permissions

### Remove Stack
```bash
docker stack rm staticman
docker config rm nginx_config
```

## GitHub App Setup

Staticman uses a GitHub App for authentication, which provides better security and permissions than personal access tokens.

### Create GitHub App

1. Go to GitHub Settings → Developer settings → GitHub Apps → New GitHub App
2. Configure:
   - **Name**: `Staticman-[your-site]` (must be unique)
   - **Homepage URL**: `https://staticman.net/`
   - **Webhook URL**: `http://YOUR_SERVER_IP/v1/webhook`
   - **Webhook secret**: Generate a random string
3. **Permissions** (Repository permissions):
   - **Contents**: Read & Write
   - **Pull requests**: Read & Write  
   - **Metadata**: Read
4. **Subscribe to events**: Pull request
5. **Install on**: Only on this account

### Install GitHub App

1. After creating the app, click "Install App"
2. Choose "Only select repositories"
3. Select your Hugo site repository
4. Complete installation

### Configure Deployment

1. **Update .env file**:
   ```env
   GITHUB_APP_ID=your_app_id
   GITHUB_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----
   your_private_key_content
   -----END RSA PRIVATE KEY-----"
   WEBHOOK_SECRET=your_webhook_secret
   ```

2. **Deploy**:
   ```bash
   ./scripts/setup.sh
   ./scripts/deploy.sh
   ```

## Contributing

1. Fork this repository
2. Create a feature branch
3. Submit a pull request

## License

MIT License - see LICENSE file for details.
