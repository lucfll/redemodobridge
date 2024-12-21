#!/bin/bash

# Verifica se o comando nmcli está disponível
if ! command -v nmcli &> /dev/null; then
    echo "O comando 'nmcli' não foi encontrado. Instalando o pacote 'network-manager'..."
    sudo apt update
    sudo apt install network-manager -y
    sudo systemctl start NetworkManager
    sudo systemctl enable NetworkManager
    echo "'network-manager' instalado e ativado com sucesso!"
fi

# Listar placas de rede disponíveis
echo "Listando placas de rede disponíveis:"
interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")
echo "$interfaces"

# Solicita ao usuário a ação desejada
echo "Escolha uma ação:"
echo "1. Configurar uma interface em modo bridge"
echo "2. Remover configuração de bridge existente"
read -p "Digite o número da sua escolha (1 ou 2): " ACTION

if [ "$ACTION" == "1" ]; then
    # Solicita ao usuário o nome da ponte a ser criada
    read -p "Digite o nome da ponte a ser criada (exemplo: bridge_lucas): " BRIDGE_NAME
    # Solicita ao usuário a interface para modo bridge
    read -p "Digite o nome da interface que deseja configurar em modo bridge (exemplo: enp1s0): " ETHERNET_NAME

    # Remove conexões anteriores com o mesmo nome, se existirem
    nmcli connection delete "$BRIDGE_NAME" &> /dev/null
    nmcli connection delete "bridge-slave-$ETHERNET_NAME" &> /dev/null

    # Cria a ponte de rede
    echo "Criando a ponte de rede $BRIDGE_NAME..."
    nmcli connection add type bridge con-name "$BRIDGE_NAME" ifname "$BRIDGE_NAME"

    # Configura a interface Ethernet como escrava da ponte
    echo "Configurando a interface $ETHERNET_NAME como escrava da ponte $BRIDGE_NAME..."
    nmcli connection add type ethernet con-name "bridge-slave-$ETHERNET_NAME" ifname "$ETHERNET_NAME" master "$BRIDGE_NAME"

    # Configura a ponte para obter IP via DHCP
    echo "Configurando a ponte para obter um IP via DHCP..."
    nmcli connection modify "$BRIDGE_NAME" ipv4.method auto ipv6.method ignore

    # Ativa as conexões
    echo "Ativando as conexões..."
    nmcli connection up "$BRIDGE_NAME"  # Ativa a ponte
    nmcli connection up "bridge-slave-$ETHERNET_NAME"  # Ativa a interface escrava

    # Ativa a interface de rede da ponte manualmente, se necessário
    ip link set "$BRIDGE_NAME" up

    # Força a interface lucas a ficar UP
    ip link set "lucas" up

    # Verifica se a ponte obteve um IP via DHCP
    echo "Verificando o estado da ponte..."
    ip a show "$BRIDGE_NAME"
    
    # Espera um momento para a obtenção de IP via DHCP
    sleep 10

    # Verifica se a ponte obteve um IP
    ip a show "$BRIDGE_NAME" | grep "inet"

    if [ $? -eq 0 ]; then
        echo "A ponte $BRIDGE_NAME obteve um IP via DHCP com sucesso."
    else
        echo "Falha ao obter um IP via DHCP na ponte $BRIDGE_NAME. Verifique a configuração da rede."
    fi

    echo "Configuração concluída."

elif [ "$ACTION" == "2" ]; then
    # Solicita ao usuário o nome da ponte a ser removida
    read -p "Digite o nome da ponte a ser removida (exemplo: bridge_lucas): " REMOVE_NAME

    # Desativa a interface bridge
    echo "Desativando a interface $REMOVE_NAME..."
    ip link set "$REMOVE_NAME" down

    # Remove as conexões de bridge
    echo "Removendo a configuração de bridge..."
    nmcli connection delete "$REMOVE_NAME" &> /dev/null

    # Verifica se a interface foi completamente removida
    if ip a show "$REMOVE_NAME" &> /dev/null; then
        echo "Erro: A interface $REMOVE_NAME ainda existe. Tentando removê-la manualmente..."
        ip link delete "$REMOVE_NAME" type bridge
    fi

    echo "Configuração de bridge removida com sucesso."

else
    echo "Opção inválida. Saindo do script."
fi

