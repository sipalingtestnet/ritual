#!/bin/bash

if [ "$(id -u)" != "0" ]; then
    echo -e "\e[1;31m✖ Skrip ini perlu dijalankan dengan hak akses root.\e[0m"
    echo -e "\e[1;33mℹ Silakan coba menggunakan perintah 'sudo -i' untuk beralih ke pengguna root, lalu jalankan skrip ini kembali.\e[0m"
    exit 1
fi

function show_header() {
    clear
    echo -e "\e[1;35m╔══════════════════════════════════════════════════════════╗"
    echo -e "║ \e[1;36m🔥 Ritual Node Installer - SIPALING-TESTNET 🔥        \e[1;35m║"
    echo -e "╚══════════════════════════════════════════════════════════╝\e[0m"
    echo ""
}

function main_menu() {
    while true; do
        show_header
        echo -e "\e[1;32m📋 Menu Utama:\e[0m"
        echo -e "\e[1;34m1. 🛠  Pasang Node Ritual"
        echo -e "2. 📜 Lihat Log Node Ritual"
        echo -e "3. 🗑  Hapus Node Ritual"
        echo -e "4. 🚪 Keluar dari skrip\e[0m"
        echo -e "\e[1;35m══════════════════════════════════════════════════════════\e[0m"
        
        read -p "➡ Masukkan pilihan Anda [1-4]: " choice

        case $choice in
            1) 
                install_ritual_node
                ;;
            2)
                view_logs
                ;;
            3)
                remove_ritual_node
                ;;
            4)
                echo -e "\e[1;32m✔ Terima kasih telah menggunakan skrip ini!\e[0m"
                exit 0
                ;;
            *)
                echo -e "\e[1;31m✖ Pilihan tidak valid, silakan coba lagi.\e[0m"
                ;;
        esac

        echo -e "\n\e[1;33mℹ Tekan sembarang tombol untuk kembali ke menu utama...\e[0m"
        read -n 1 -s
    done
}

function install_ritual_node() {
    show_header
    echo -e "\e[1;32m🚀 Memulai proses instalasi Node Ritual...\e[0m\n"
    
    echo -e "\e[1;34m🔄 Memperbarui sistem...\e[0m"
    sudo apt update && sudo apt upgrade -y
    
    echo -e "\e[1;34m📦 Memasang paket yang diperlukan...\e[0m"
    sudo apt -qy install curl git jq lz4 build-essential screen

    if ! command -v docker &> /dev/null; then
        echo -e "\e[1;34m🐳 Memasang Docker...\e[0m"
        sudo apt -qy install docker.io
    else
        echo -e "\e[1;32m✔ Docker sudah terpasang\e[0m"
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo -e "\e[1;34m🐳 Memasang Docker Compose...\e[0m"
        sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo -e "\e[1;32m✔ Docker Compose sudah terpasang\e[0m"
    fi

    echo -e "\n\e[1;34m⬇ Mengunduh repositori dari GitHub...\e[0m"
    git clone https://github.com/ritual-net/infernet-container-starter ~/infernet-container-starter
    cd ~/infernet-container-starter

    echo -e "\e[1;33m🔑 Silakan masukkan private key wallet Anda:\e[0m"
    read -s PRIVATE_KEY

    echo -e "\e[1;34m📝 Membuat file konfigurasi...\e[0m"
    cat > deploy/config.json <<EOL
{
    "log_path": "infernet_node.log",
    "server": {
        "port": 4000,
        "rate_limit": {
            "num_requests": 100,
            "period": 100
        }
    },
    "chain": {
        "enabled": true,
        "trail_head_blocks": 3,
        "rpc_url": "https://mainnet.base.org/",
        "registry_address": "0x3B1554f346DFe5c482Bb4BA31b880c1C18412170",
        "wallet": {
          "max_gas_limit": 4000000,
          "private_key": "$PRIVATE_KEY",
          "allowed_sim_errors": []
        },
        "snapshot_sync": {
          "sleep": 3,
          "batch_size": 10000,
          "starting_sub_id": 180000,
          "sync_period": 30
        }
    },
    "startup_wait": 1.0,
    "redis": {
        "host": "redis",
        "port": 6379
    },
    "forward_stats": true,
    "containers": [
        {
            "id": "hello-world",
            "image": "ritualnetwork/hello-world-infernet:latest",
            "external": true,
            "port": "3000",
            "allowed_delegate_addresses": [],
            "allowed_addresses": [],
            "allowed_ips": [],
            "command": "--bind=0.0.0.0:3000 --workers=2",
            "env": {},
            "volumes": [],
            "accepted_payments": {},
            "generates_proofs": false
        }
    ]
}
EOL

    echo -e "\e[1;34m⚙ Memasang Foundry...\e[0m"
    mkdir -p ~/foundry && cd ~/foundry
    curl -L https://foundry.paradigm.xyz | bash
    export PATH="$HOME/.foundry/bin:$PATH"
    source ~/.bashrc
    sleep 2

    if [ -f "$HOME/.foundry/bin/foundryup" ]; then
        $HOME/.foundry/bin/foundryup
    else
        if command -v foundryup &> /dev/null; then
            foundryup
        else
            echo -e "\e[1;31m✖ Gagal memasang Foundry\e[0m"
            exit 1
        fi
    fi

    echo -e "\e[1;34m📦 Memasang dependensi kontrak...\e[0m"
    cd ~/infernet-container-starter/projects/hello-world/contracts
    rm -rf lib/forge-std
    rm -rf lib/infernet-sdk

    if ! command -v forge &> /dev/null; then
        ~/.foundry/bin/forge install --no-commit foundry-rs/forge-std
        ~/.foundry/bin/forge install --no-commit ritual-net/infernet-sdk
    else
        forge install --no-commit foundry-rs/forge-std
        forge install --no-commit ritual-net/infernet-sdk
    fi

    echo -e "\e[1;34m🐳 Menjalankan Docker Compose...\e[0m"
    cd ~/infernet-container-starter
    docker compose -f deploy/docker-compose.yaml up -d

    echo -e "\e[1;34m📄 Menerapkan kontrak...\e[0m"
    project=hello-world make deploy-contracts

    echo -e "\n\e[1;32m🎉 Node Ritual berhasil terpasang!\e[0m"
    echo -e "\e[1;33mℹ Untuk memeriksa log node, jalankan opsi 2 dari menu utama.\e[0m"
}

function view_logs() {
    show_header
    echo -e "\e[1;32m📜 Menampilkan log Node Ritual...\e[0m"
    echo -e "\e[1;33mℹ Tekan Ctrl+C untuk keluar dari tampilan log\e[0m\n"
    docker logs -f infernet-node
}

function remove_ritual_node() {
    show_header
    echo -e "\e[1;31m⚠ PERINGATAN: Anda akan menghapus Node Ritual!\e[0m"
    read -p "➡ Apakah Anda yakin ingin melanjutkan? [y/N]: " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo -e "\e[1;34m🛑 Menghentikan container Docker...\e[0m"
        docker-compose -f ~/infernet-container-starter/deploy/docker-compose.yaml down
        
        echo -e "\e[1;34m🧹 Membersihkan file...\e[0m"
        rm -rf ~/infernet-container-starter
        
        echo -e "\e[1;34m🗑  Menghapus image Docker...\e[0m"
        docker rmi ritualnetwork/hello-world-infernet:latest
        
        echo -e "\n\e[1;32m✔ Node Ritual berhasil dihapus!\e[0m"
    else
        echo -e "\e[1;33m❌ Penghapusan dibatalkan\e[0m"
    fi
}

main_menu
