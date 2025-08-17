#!/bin/bash
# Master setup script for production-ready PostgreSQL
# This script initializes the entire production environment

set -e

echo "🚀 PostgreSQL Production Setup Initialization"
echo "=============================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}==== $1 ====${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_status "Docker: $(docker --version)"
    
    # Check Docker Compose
    if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
        print_error "Docker Compose (plugin) is not installed"
        exit 1
    fi
    print_status "Docker Compose: $(docker compose version)"
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running"
        exit 1
    fi
    print_status "Docker daemon is running"
}

# Setup environment
setup_environment() {
    print_header "Setting up Environment"
    
    if [ ! -f .env ]; then
        print_status "Creating .env from template..."
        cp .env.template .env
        print_warning "Please edit .env file with your secure passwords!"
        print_warning "Default passwords are NOT secure for production!"
    else
        print_status ".env file already exists"
    fi
    
    # Create necessary directories
    print_status "Creating directories..."
    mkdir -p logs backups data/postgres data/pgladmin ssl
    
    # Set permissions
    chmod 755 scripts/*.sh
    print_status "Set executable permissions on scripts"
}

# Initialize services
initialize_services() {
    print_header "Initializing Services"
    
    print_status "Starting production services..."
    if docker compose -f docker-compose.prod.yml up -d; then
        print_status "Services started successfully"
    else
        print_error "Failed to start services"
        exit 1
    fi
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready..."
    sleep 30
    
    # Check health
    if make health &> /dev/null; then
        print_status "Health check passed"
    else
        print_warning "Health check failed - services may still be starting"
    fi
}

# Setup monitoring
setup_monitoring() {
    print_header "Setting up Monitoring"
    
    print_status "Running initial health check..."
    ./scripts/monitor.sh
    
    print_status "Running security audit..."
    ./scripts/security-audit.sh
}

# Setup automation
setup_automation() {
    print_header "Setting up Automation"
    
    print_status "Installing cron jobs..."
    ./scripts/setup-cron.sh
    
    print_status "Cron jobs installed for:"
    echo "  • Daily backups"
    echo "  • Health monitoring"
    echo "  • Security audits"
    echo "  • Database maintenance"
}

# Final verification
final_verification() {
    print_header "Final Verification"
    
    # Check services
    print_status "Checking service status..."
    docker compose -f docker-compose.prod.yml ps
    
    # Test database connection
    print_status "Testing database connection..."
    if docker exec postgres_primary pg_isready -U postgres_admin -d production_db &> /dev/null; then
        print_status "Database connection: OK"
    else
        print_error "Database connection: FAILED"
    fi
    
    # Test pgladmin
    print_status "Testing pgAdmin..."
    if docker exec pgladmin_web wget --quiet --tries=1 --spider http://localhost/misc/ping &> /dev/null; then
        print_status "pgAdmin: OK"
    else
        print_warning "pgAdmin: May still be starting"
    fi
}

# Print completion summary
print_summary() {
    print_header "Setup Complete"
    
    echo ""
    echo "🎉 Production PostgreSQL setup completed successfully!"
    echo ""
    echo "📊 Access Points:"
    echo "  • Database: localhost:5432"
    echo "  • pgAdmin: http://localhost:5050"
    echo ""
    echo "🔑 Credentials:"
    echo "  • Check your .env file for passwords"
    echo "  • IMPORTANT: Change default passwords before production use!"
    echo ""
    echo "📋 Available Commands:"
    echo "  • make help          - Show all commands"
    echo "  • make status        - Check service status"
    echo "  • make monitor       - Run health check"
    echo "  • make backup        - Create backup"
    echo "  • make security      - Security audit"
    echo ""
    echo "📖 Documentation:"
    echo "  • README.md          - Basic usage"
    echo "  • PRODUCTION_GUIDE.md - Complete production guide"
    echo ""
    echo "🔧 Next Steps:"
    echo "  1. Edit .env with secure passwords"
    echo "  2. Configure SSL certificates (optional)"
    echo "  3. Set up external backup storage"
    echo "  4. Configure alerting (Slack/email)"
    echo "  5. Test disaster recovery procedures"
    echo ""
    echo "🚨 Security Reminder:"
    echo "  • Change all default passwords"
    echo "  • Enable SSL for production"
    echo "  • Regularly update and patch"
    echo "  • Monitor security logs"
    echo ""
    print_status "Setup completed at $(date)"
}

# Main execution
main() {
    check_prerequisites
    setup_environment
    
    # Ask for confirmation to continue
    echo ""
    echo -e "${YELLOW}This will set up a production PostgreSQL environment.${NC}"
    echo -e "${YELLOW}Make sure to review and edit the .env file with secure passwords.${NC}"
    echo ""
    read -p "Continue with setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Setup cancelled"
        exit 0
    fi
    
    initialize_services
    setup_monitoring
    setup_automation
    final_verification
    print_summary
}

# Run main function
main "$@"
