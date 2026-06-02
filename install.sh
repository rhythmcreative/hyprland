#!/bin/bash

# --- Rhythm Arch Hyprland Installer v3 (Minimal White) ---

# Colors & Aesthetic (Synchronized with Terminal Theme)
# We set these environment variables to ensure 'gum' uses terminal defaults
export GUM_CHOOSE_CURSOR_FOREGROUND="7"
export GUM_CHOOSE_HEADER_FOREGROUND="7"
export GUM_CHOOSE_SELECTED_FOREGROUND="7"
export GUM_SPIN_SPINNER_FOREGROUND="7"
export GUM_STYLE_FOREGROUND="7"
export GUM_CONFIRM_PROMPT_FOREGROUND="7"
export GUM_CONFIRM_SELECTED_BACKGROUND="7"
export GUM_CONFIRM_SELECTED_FOREGROUND="0"

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# --- LOCALIZATION ---
setup_language() {
    LANG_CHOICE=$(gum choose --header "Select Language / Selecciona Idioma / Choisir la langue" \
        "English" "Español" "Français" "Deutsch" "Italiano" "Português" "Русский" "中文" "日本語" "한국어")
    
    case "$LANG_CHOICE" in
        "Español")
            MSG_ERROR_ROOT=" [ERROR] No ejecutes este script como root."
            MSG_SECTION=" SECCION: "
            MSG_CORE_INSTALL="Instalando nucleo del sistema..."
            MSG_SEARCH_PROMPT="Buscar Apps: "
            MSG_SEARCH_HEADER="[TAB] Seleccionar | [ENTER] Instalar | [ESC] Omitir"
            MSG_SEARCH_LAUNCH="Lanzando herramienta de busqueda (Oficial + AUR)..."
            MSG_DRIVER_HEADER="DRIVERS GRAFICOS (Selecciona tu hardware)"
            MSG_DEPLOY_DRIVERS="Instalando drivers de hardware..."
            MSG_FLATPAK_CONFIRM="¿Instalar Flatpaks de tu lista flatpaks.txt?"
            MSG_WALL_CONFIRM="¿Descargar fondos de pantalla personalizados?"
            MSG_ZSH_CONFIRM="¿Establecer Zsh como shell por defecto?"
            MSG_SERVICES_CONFIRM="¿Habilitar servicios principales (Red/BT/Login)?"
            MSG_DONE="Despliegue completado con exito."
            ;;
        "Français")
            MSG_ERROR_ROOT=" [ERREUR] Ne pas executer ce script en tant que root."
            MSG_SECTION=" SECTION : "
            MSG_CORE_INSTALL="Installation du noyau du systeme..."
            MSG_SEARCH_PROMPT="Rechercher des applications : "
            MSG_SEARCH_HEADER="[TAB] Selectionner | [ENTER] Installer | [ESC] Passer"
            MSG_SEARCH_LAUNCH="Lancement de l'outil de recherche (Officiel + AUR)..."
            MSG_DRIVER_HEADER="PILOTES GRAPHIQUES (Selectionnez votre materiel)"
            MSG_DEPLOY_DRIVERS="Deploiement des pilotes materiels..."
            MSG_FLATPAK_CONFIRM="Installer les Flatpaks de votre liste flatpaks.txt ?"
            MSG_WALL_CONFIRM="Telecharger les fonds d'ecran personnalises ?"
            MSG_ZSH_CONFIRM="Definir Zsh comme shell par defaut ?"
            MSG_SERVICES_CONFIRM="Activer les services de base (Reseau/BT/Login) ?"
            MSG_DONE="Systeme reconfigure avec succes. Deploiement termine."
            ;;
        "Deutsch")
            MSG_ERROR_ROOT=" [FEHLER] Fuhren Sie dieses Skript nicht als Root aus."
            MSG_SECTION=" ABSCHNITT: "
            MSG_CORE_INSTALL="Systemkern wird installiert..."
            MSG_SEARCH_PROMPT="Apps suchen: "
            MSG_SEARCH_HEADER="[TAB] Mehrfachauswahl | [ENTER] Installieren | [ESC] Uberspringen"
            MSG_SEARCH_LAUNCH="Interaktives Suchwerkzeug wird gestartet (Offiziell + AUR)..."
            MSG_DRIVER_HEADER="GRAFIKTREIBER (Wahlen Sie Ihre Hardware aus)"
            MSG_DEPLOY_DRIVERS="Hardwaretreiber werden bereitgestellt..."
            MSG_FLATPAK_CONFIRM="Flatpaks aus Ihrer flatpaks.txt-Liste installieren?"
            MSG_WALL_CONFIRM="Benutzerdefinierte Hintergrundbilder herunterladen?"
            MSG_ZSH_CONFIRM="Zsh als Standardshell festlegen?"
            MSG_SERVICES_CONFIRM="Kerndienste aktivieren (Netzwerk/BT/Login)?"
            MSG_DONE="System erfolgreich rekonfiguriert. Bereitstellung abgeschlossen."
            ;;
        "Italiano")
            MSG_ERROR_ROOT=" [ERRORE] Non eseguire questo script como root."
            MSG_SECTION=" SEZIONE: "
            MSG_CORE_INSTALL="Installazione del core del sistema..."
            MSG_SEARCH_PROMPT="Cerca app: "
            MSG_SEARCH_HEADER="[TAB] Selezione multipla | [ENTER] Installa | [ESC] Salta"
            MSG_SEARCH_LAUNCH="Avvio dello strumento di ricerca (Ufficiale + AUR)..."
            MSG_DRIVER_HEADER="DRIVER GRAFICI (Seleziona il tuo hardware)"
            MSG_DEPLOY_DRIVERS="Distribuzione dei driver hardware..."
            MSG_FLATPAK_CONFIRM="Installare i Flatpak dalla lista flatpaks.txt?"
            MSG_WALL_CONFIRM="Scaricare sfondi personalizzati?"
            MSG_ZSH_CONFIRM="Impostare Zsh como shell predefinita?"
            MSG_SERVICES_CONFIRM="Abilitare i servicios principali (Rete/BT/Login)?"
            MSG_DONE="Sistema riconfigurato con successo. Distribuzione completata."
            ;;
        "Português")
            MSG_ERROR_ROOT=" [ERRO] Nao execute este script como root."
            MSG_SECTION=" SEÇÃO: "
            MSG_CORE_INSTALL="Instalando o nucleo do sistema..."
            MSG_SEARCH_PROMPT="Buscar Apps: "
            MSG_SEARCH_HEADER="[TAB] Selecionar | [ENTER] Instalar | [ESC] Pular"
            MSG_SEARCH_LAUNCH="Iniciando ferramenta de busca (Oficial + AUR)..."
            MSG_DRIVER_HEADER="DRIVERS GRAFICOS (Selecione seu hardware)"
            MSG_DEPLOY_DRIVERS="Implantando drivers de hardware..."
            MSG_FLATPAK_CONFIRM="Instalar Flatpaks da sua lista flatpaks.txt?"
            MSG_WALL_CONFIRM="Baixar papeis de parede personalizados?"
            MSG_ZSH_CONFIRM="Definir Zsh como shell padrao?"
            MSG_SERVICES_CONFIRM="Ativar servicos principais (Rede/BT/Login)?"
            MSG_DONE="Sistema reconfigurado com sucesso. Implantacao concluida."
            ;;
        "Русский")
            MSG_ERROR_ROOT=" [ОШИБКА] Не запускайте этот скрипт от имени root."
            MSG_SECTION=" РАЗДЕЛ: "
            MSG_CORE_INSTALL="Установка ядра системы..."
            MSG_SEARCH_PROMPT="Поиск приложений: "
            MSG_SEARCH_HEADER="[TAB] Выбрать несколько | [ENTER] Установить | [ESC] Пропустить"
            MSG_SEARCH_LAUNCH="Запуск интерактивного поиска (Официальный + AUR)..."
            MSG_DRIVER_HEADER="ГРАФИЧЕСКИЕ ДРАЙВЕРЫ (Выберите ваше оборудование)"
            MSG_DEPLOY_DRIVERS="Развертывание драйверов оборудования..."
            MSG_FLATPAK_CONFIRM="Установить Flatpaks из списка flatpaks.txt?"
            MSG_WALL_CONFIRM="Загрузить пользовательские обои?"
            MSG_ZSH_CONFIRM="Установить Zsh в качестве оболочки по умолчанию?"
            MSG_SERVICES_CONFIRM="Включить основные службы (Сеть/BT/Вход)?"
            MSG_DONE="Система успешно перенастроена. Развертывание завершено."
            ;;
        "中文")
            MSG_ERROR_ROOT=" [错误] 请勿以 root 身份运行此脚本。"
            MSG_SECTION=" 章节: "
            MSG_CORE_INSTALL="正在安装系统核心..."
            MSG_SEARCH_PROMPT="搜索应用: "
            MSG_SEARCH_HEADER="[TAB] 多选 | [ENTER] 安装 | [ESC] 跳过"
            MSG_SEARCH_LAUNCH="启动交互式搜索工具 (官方 + AUR)..."
            MSG_DRIVER_HEADER="图形驱动程序 (选择您的硬件)"
            MSG_DEPLOY_DRIVERS="部署硬件驱动程序..."
            MSG_FLATPAK_CONFIRM="是否从 flatpaks.txt 列表安装 Flatpaks？"
            MSG_WALL_CONFIRM="是否下载自定义壁纸资源？"
            MSG_ZSH_CONFIRM="是否将 Zsh 设置为默认 Shell？"
            MSG_SERVICES_CONFIRM="是否启用核心服务 (网络/蓝牙/登录)？"
            MSG_DONE="系统重配置成功。部署完成。"
            ;;
        "日本語")
            MSG_ERROR_ROOT=" [エラー] このスクリプトをrootとして実行しないでください。"
            MSG_SECTION=" セクション: "
            MSG_CORE_INSTALL="システムコアをインストールしています..."
            MSG_SEARCH_PROMPT="アプリを検索: "
            MSG_SEARCH_HEADER="[TAB] 複数選択 | [ENTER] インストール | [ESC] スキップ"
            MSG_SEARCH_LAUNCH="インタラクティブ検索ツールを起動しています (公式 + AUR)..."
            MSG_DRIVER_HEADER="グラフィックドライバー (ハードウェアを選択してください)"
            MSG_DEPLOY_DRIVERS="ハードウェアドライバーを展開しています..."
            MSG_FLATPAK_CONFIRM="flatpaks.txtリストからFlatpaksをインストールしますか？"
            MSG_WALL_CONFIRM="カスタム壁紙をダウンロードしますか？"
            MSG_ZSH_CONFIRM="Zshをデフォルトのシェルに設定しますか？"
            MSG_SERVICES_CONFIRM="コアサービス (ネットワーク/BT/ログイン) を有効にしますか？"
            MSG_DONE="システムの再設定が成功しました。展開が完了しました。"
            ;;
        "한국어")
            MSG_ERROR_ROOT=" [오류] 이 스크립트를 root로 실행하지 마십시오."
            MSG_SECTION=" 섹션: "
            MSG_CORE_INSTALL="시스템 코어 설치 중..."
            MSG_SEARCH_PROMPT="앱 검색: "
            MSG_SEARCH_HEADER="[TAB] 다중 선택 | [ENTER] 설치 | [ESC] 건너뛰기"
            MSG_SEARCH_LAUNCH="대화형 검색 도구 실행 중 (공식 + AUR)..."
            MSG_DRIVER_HEADER="그래픽 드라이버 (하드웨어 선택)"
            MSG_DEPLOY_DRIVERS="하드웨어 드라이버 배포 중..."
            MSG_FLATPAK_CONFIRM="flatpaks.txt 목록에서 Flatpaks를 설치하시겠습니까?"
            MSG_WALL_CONFIRM="사용자 정의 배경화면을 다운로드하시겠습니까?"
            MSG_ZSH_CONFIRM="Zsh를 기본 셸로 설정하시겠습니까?"
            MSG_SERVICES_CONFIRM="핵심 서비스 (네트워크/BT/로그인)를 활성화하시겠습니까?"
            MSG_DONE="시스템 재구성이 성공적으로 완료되었습니다. 배포 완료."
            ;;
        *)
            # Default to English
            MSG_ERROR_ROOT=" [ERROR] Do not run this script as root."
            MSG_SECTION=" SECTION: "
            MSG_CORE_INSTALL="Installing system core..."
            MSG_SEARCH_PROMPT="Search Apps: "
            MSG_SEARCH_HEADER="[TAB] Select Multiple | [ENTER] Install | [ESC] Skip"
            MSG_SEARCH_LAUNCH="Launching Interactive Search Tool (Official + AUR)..."
            MSG_DRIVER_HEADER="GRAPHICS DRIVERS (Select your hardware)"
            MSG_DEPLOY_DRIVERS="Deploying hardware drivers..."
            MSG_FLATPAK_CONFIRM="Install Flatpaks from your flatpaks.txt list?"
            MSG_WALL_CONFIRM="Download custom wallpaper assets?"
            MSG_ZSH_CONFIRM="Set Zsh as your default shell?"
            MSG_SERVICES_CONFIRM="Enable core services (Net/BT/Login)?"
            MSG_DONE="System successfully reconfigured. Deployment complete."
            ;;
    esac
}

# --- INITIAL SETUP ---
if [ "$EUID" -eq 0 ]; then
    echo "Do not run as root."
    exit 1
fi

# Ensure core dependencies are installed
if ! command -v gum > /dev/null || ! command -v fzf > /dev/null; then
    sudo pacman -S --needed --noconfirm gum fzf git base-devel stow zsh curl > /dev/null 2>&1
fi

setup_language

# --- UI COMPONENTS ---

print_banner() {
    clear
    # ASCII Art using terminal default foreground color
    echo "██████╗ ██╗  ██╗██╗   ██╗████████╗██╗  ██╗███╗   ███╗ ██████╗██████╗ ███████╗ █████╗ ████████╗██╗██╗   ██╗███████╗"
    echo "██╔══██╗██║  ██║╚██╗ ██╔╝╚══██╔══╝██║  ██║████╗ ████║██╔════╝██╔══██╗██╔════╝██╔══██╗╚══██╔══╝██║██║   ██║██╔════╝"
    echo "██████╔╝███████║ ╚████╔╝    ██║   ███████║██╔████╔██║██║     ██████╔╝█████╗  ███████║   ██║   ██║██║   ██║█████╗  "
    echo "██╔══██╗██╔══██║  ╚██╔╝     ██║   ██╔══██║██║╚██╔╝██║██║     ██╔══██╗██╔══╝  ██╔══██║   ██║   ██║╚██╗ ██╔╝██╔══╝  "
    echo "██║  ██║██║  ██║   ██║      ██║   ██║  ██║██║ ╚═╝ ██║╚██████╗██║  ██║███████╗██║  ██║   ██║   ██║ ╚████╔╝ ███████╗"
    echo "╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═══╝  ╚══════╝"
    echo ""
    echo "██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗"
    echo "██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝"
    echo "██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗"
    echo "██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║"
    echo "██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║"
    echo "╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝"
    echo ""
}

section() {
    echo ""
    gum style --bold --margin "1 0" --underline "$MSG_SECTION $1 "
}

info() {
    echo "  [SYSTEM] $1"
}

success() {
    echo "  [DONE] $1"
}

# --- LOGIC ---

install_yay() {
    if ! command -v yay > /dev/null; then
        section "DEPENDENCY: AUR HELPER"
        gum spin --spinner dot --title "Deploying yay..." -- sleep 2
        git clone https://aur.archlinux.org/yay.git /tmp/yay > /dev/null 2>&1
        cd /tmp/yay && makepkg -si --noconfirm > /dev/null 2>&1
        cd "$DOTFILES_DIR"
        success "yay helper initialized."
    fi
}

unified_app_search() {
    section "UNIFIED APPLICATION DISCOVERY"
    info "$MSG_SEARCH_LAUNCH"
    
    # Configuration for fzf to provide a rich preview of pacman/yay packages
    fzf_args=(
      --multi
      --ansi
      --prompt="$MSG_SEARCH_PROMPT"
      --header="$MSG_SEARCH_HEADER"
      --preview 'yay -Si {1} 2>/dev/null || echo "Loading info..." '
      --preview-window 'right:60%:wrap'
      --bind 'change:top'
    )

    # Fetch all available packages from repositories and AUR
    SELECTED_APPS=$(yay -Slqa | fzf "${fzf_args[@]}")

    if [[ -n "$SELECTED_APPS" ]]; then
        info "Deploying selected applications..."
        yay -S --needed --noconfirm $SELECTED_APPS
        success "Applications installed."
    else
        info "No additional applications selected."
    fi
}

step_software() {
    section "CORE SYSTEM DEPLOYMENT"
    
    CORE_PKGS="hyprland sddm hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland waybar rofi kitty networkmanager network-manager-applet bluez bluez-utils pipewire pipewire-pulse wireplumber pavucontrol playerctl pamixer brightnessctl gvfs polkit-kde-agent swappy grim slurp nwg-look bibata-cursor-theme tela-circle-icon-theme-all otf-font-awesome ttf-jetbrains-mono-nerd flatpak python-pywal awww stow qt5-graphicaleffects qt5-quickcontrols2 qt5-svg qt5-declarative curl unzip zsh-autosuggestions zsh-syntax-highlighting ulauncher nwg-displays wl-clipboard xdg-utils jq bc quickshell-git imagemagick htop fastfetch bluez-obex gwenview"
    
    info "$MSG_CORE_INSTALL"
    yay -S --needed --noconfirm $CORE_PKGS

    section "CUSTOM MODULE DEPLOYMENT"
    
    # 1. GRAPHICS & DRIVERS
    SELECTED_DRIVERS=$(gum choose --no-limit --header "$MSG_DRIVER_HEADER" \
        "NVIDIA Proprietary" \
        "NVIDIA Open-Source (DKMS)" \
        "AMD Open-Source (Mesa)" \
        "Intel Graphics" \
        "ASUS Laptop Tools" \
        "Surface Laptop Tools")

    EXTRA_PKGS=""
    
    # Process Drivers
    [[ $SELECTED_DRIVERS == *"NVIDIA Proprietary"* ]] && EXTRA_PKGS="$EXTRA_PKGS nvidia nvidia-settings nvidia-utils"
    [[ $SELECTED_DRIVERS == *"NVIDIA Open-Source (DKMS)"* ]] && EXTRA_PKGS="$EXTRA_PKGS nvidia-open-dkms nvidia-settings nvidia-utils"
    [[ $SELECTED_DRIVERS == *"AMD Open-Source (Mesa)"* ]] && EXTRA_PKGS="$EXTRA_PKGS lib32-mesa vulkan-radeon lib32-vulkan-radeon mesa-utils"
    [[ $SELECTED_DRIVERS == *"Intel Graphics"* ]] && EXTRA_PKGS="$EXTRA_PKGS intel-media-driver libva-intel-driver vulkan-intel"
    [[ $SELECTED_DRIVERS == *"ASUS Laptop Tools"* ]] && EXTRA_PKGS="$EXTRA_PKGS asusctl supergfxctl rog-control-center"
    [[ $SELECTED_DRIVERS == *"Surface Laptop Tools"* ]] && EXTRA_PKGS="$EXTRA_PKGS linux-surface linux-surface-headers surface-control"

    if [ ! -z "$EXTRA_PKGS" ]; then
        info "$MSG_DEPLOY_DRIVERS"
        yay -S --needed --noconfirm $EXTRA_PKGS
    fi

    # Interactive Application Discovery
    unified_app_search

    if gum confirm "$MSG_FLATPAK_CONFIRM"; then
        if [ -f "$DOTFILES_DIR/flatpaks.txt" ]; then
            section "FLATPAK DEPLOYMENT"
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            while read -r app; do
                [ -z "$app" ] || [[ "$app" =~ ^# ]] && continue
                info "Installing: $app"
                sudo flatpak install -y --system flathub "$app"
            done < "$DOTFILES_DIR/flatpaks.txt"
        fi
    fi
}

step_dotfiles() {
    section "DOTFILES SYNC"
    # Ensure base directories exist
    mkdir -p ~/.config ~/.local/bin
    
    cd "$DOTFILES_DIR"

    info "Copying configurations..."
    
    # 1. Handle .config (Copy each item individually to ~/.config/)
    for item in .config/*; do
        [ -e "$item" ] || continue
        name=$(basename "$item")
        target="$HOME/.config/$name"
        
        if [ -e "$target" ]; then
            info "Backing up existing .config/$name"
            mv "$target" "$target.bak"
        fi
        
        cp -r "$DOTFILES_DIR/.config/$name" "$target"
        echo "  COPY: $name => ~/.config/$name"
    done

    # 2. Handle .local/bin (Copy each file individually to ~/.local/bin/)
    for file in .local/bin/*; do
        [ -e "$file" ] || continue
        name=$(basename "$file")
        target="$HOME/.local/bin/$name"
        
        if [ -e "$target" ]; then
            mv "$target" "$target.bak"
        fi
        
        cp "$DOTFILES_DIR/$file" "$target"
        chmod +x "$target"
    done
    echo "  COPY: bin contents => ~/.local/bin/"

    # 3. Handle other packages (zsh, bash, gtk) that go into $HOME
    for pkg in zsh bash gtk; do
        if [ -d "$pkg" ]; then
            find "$pkg" -mindepth 1 -maxdepth 1 -name ".*" | while read -r file; do
                name=$(basename "$file")
                target="$HOME/$name"
                
                if [ -e "$target" ]; then
                    info "Backing up existing $name"
                    mv "$target" "$target.bak"
                fi
                
                cp -r "$DOTFILES_DIR/$file" "$target"
                echo "  COPY: $name => ~/$name"
            done
        fi
    done
    
    success "Local configs copied (Physical installation complete)."
    
    info "Fixing hardcoded paths for current user..."
    # Replace hardcoded home path in copied text files
    grep -rIl "/home/rhythmcreative" "$HOME/.config" "$HOME/.local/bin" "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.gtkrc-2.0" 2>/dev/null | while read -r file; do
        sed -i "s|/home/rhythmcreative|$HOME|g" "$file"
        echo "  FIXED: $file"
    done
}

step_wallpapers() {
    section "NEURAL WALLPAPER PACKS"
    if gum confirm "$MSG_WALL_CONFIRM"; then
        WALL_DIR="$HOME/Pictures/Wallpapers"
        mkdir -p "$WALL_DIR"
        TEMP_WALL="/tmp/wallpaper_install"
        mkdir -p "$TEMP_WALL"
        
        REPO_URL="https://raw.githubusercontent.com/rhythmcreative/wallpapers/main"
        
        HEADER_TEXT="Select download protocol"
        [ "$LANG_CHOICE" == "Español" ] && HEADER_TEXT="Selecciona el protocolo de descarga"

        CHOICE=$(gum choose --header "$HEADER_TEXT" \
            "DEPLOY ALL PACKS (4GB+)" \
            "SELECT SPECIFIC PACKS" \
            "RANDOM NEURAL SELECTION" \
            "ABORT")
        
        if [ "$CHOICE" == "DEPLOY ALL PACKS (4GB+)" ]; then
            for i in {1..49}; do
                info "Downloading pack $i/49..."
                curl -L "$REPO_URL/pack_$i.zip" -o "$TEMP_WALL/pack_$i.zip"
                unzip -q -o "$TEMP_WALL/pack_$i.zip" -d "$TEMP_WALL"
                [ -d "$TEMP_WALL/pack_$i" ] && cp -r "$TEMP_WALL/pack_$i"/* "$WALL_DIR/" && rm -rf "$TEMP_WALL/pack_$i"
                rm "$TEMP_WALL/pack_$i.zip"
            done
        elif [ "$CHOICE" == "SELECT SPECIFIC PACKS" ]; then
            PLACEHOLDER="Numbers separated by space (e.g., 1 5 40)"
            [ "$LANG_CHOICE" == "Español" ] && PLACEHOLDER="Numeros separados por espacios (ej: 1 5 40)"
            PACKS=$(gum input --placeholder "$PLACEHOLDER")
            for p in $PACKS; do
                info "Downloading pack $p..."
                curl -L "$REPO_URL/pack_$p.zip" -o "$TEMP_WALL/pack_$p.zip"
                unzip -q -o "$TEMP_WALL/pack_$p.zip" -d "$TEMP_WALL"
                [ -d "$TEMP_WALL/pack_$p" ] && cp -r "$TEMP_WALL/pack_$p"/* "$WALL_DIR/" && rm -rf "$TEMP_WALL/pack_$p"
                rm "$TEMP_WALL/pack_$p.zip"
            done
        elif [ "$CHOICE" == "RANDOM NEURAL SELECTION" ]; then
            info "Choosing 3 random archives..."
            for i in {1..3}; do
                p=$(shuf -i 1-49 -n 1)
                info "Downloading pack $p..."
                curl -L "$REPO_URL/pack_$p.zip" -o "$TEMP_WALL/pack_$p.zip"
                unzip -q -o "$TEMP_WALL/pack_$p.zip" -d "$TEMP_WALL"
                [ -d "$TEMP_WALL/pack_$p" ] && cp -r "$TEMP_WALL/pack_$p"/* "$WALL_DIR/" && rm -rf "$TEMP_WALL/pack_$p"
                rm "$TEMP_WALL/pack_$p.zip"
            done
        fi
        rm -rf "$TEMP_WALL"
        success "Wallpapers localized."
    fi
}

step_system() {
    section "SYSTEM FINALIZATION"
    
    if gum confirm "$MSG_ZSH_CONFIRM"; then
        [ "$SHELL" != "$(which zsh)" ] && sudo chsh -s "$(which zsh)" "$USER"
    fi

    if gum confirm "$MSG_SERVICES_CONFIRM"; then
        sudo systemctl enable NetworkManager bluetooth sddm
        
        if [ -d "$DOTFILES_DIR/sddm/sddm-astronaut-theme" ]; then
            sudo mkdir -p /usr/share/sddm/themes
            sudo cp -r "$DOTFILES_DIR/sddm/sddm-astronaut-theme" /usr/share/sddm/themes/
            sudo mkdir -p /etc/sddm.conf.d
            echo -e "[Theme]\nCurrent=sddm-astronaut-theme" | sudo tee /etc/sddm.conf.d/theme.conf > /dev/null
        fi
        success "Services operational."
    fi

    sudo usermod -aG video,input,render,wheel $USER
}

# --- EXECUTION ---

print_banner
gum spin --spinner pulse --title "ACCESSING SYSTEM CORE..." -- sleep 2

install_yay
step_software
step_dotfiles
step_wallpapers
step_system

# Final master sync
if [ -f "$HOME/.local/bin/modern-pywal-sync" ]; then
    gum spin --spinner moon --title "CALIBRATING COLORS..." -- bash "$HOME/.local/bin/modern-pywal-sync"
fi

section "DEPLOYMENT COMPLETE"
echo "$MSG_DONE"

# Start graphical environment automatically
sudo systemctl start sddm
