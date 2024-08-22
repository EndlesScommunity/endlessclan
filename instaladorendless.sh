#!/bin/bash

# Mostrar el mensaje de bienvenida
clear
echo "========================================"
echo "       Nick Pezo Support"
echo "========================================"
echo "Bienvenido al instalador automático del bot de WhatsApp."
echo "Este script configurará el bot en tu servidor."

# Solicitar información al usuario
echo ""
read -p "Ingrese el dominio (ejemplo: botwhat.com): " DOMAIN
read -p "Ingrese el correo electrónico de administrador: " EMAIL

# Confirmar la información ingresada
echo ""
echo "Dominio ingresado: $DOMAIN"
echo "Correo electrónico de administrador: $EMAIL"
echo ""
read -p "¿Es correcto? (s/n): " CONFIRM
if [[ "$CONFIRM" != "s" ]]; then
    echo "Instalación cancelada. Por favor, vuelva a ejecutar el script."
    exit 1
fi

# Actualizar el sistema
echo "Actualizando el sistema..."
sudo apt update && sudo apt upgrade -y

# Instalar Nginx si no está instalado
if ! command -v nginx &> /dev/null
then
    echo "Nginx no está instalado. Instalando Nginx..."
    sudo apt install nginx -y
fi

# Configurar Nginx para el dominio
echo "Configurando Nginx para el dominio $DOMAIN..."
sudo bash -c "cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF"

# Activar la configuración de Nginx para el dominio
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Instalar nvm (Node Version Manager)
echo "Instalando nvm (Node Version Manager)..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Instalar Node.js 18.2 usando nvm
echo "Instalando Node.js 18.2..."
nvm install 18.2.0
nvm use 18.2.0
nvm alias default 18.2.0

# Verificar la versión de Node.js y npm
echo "Verificando las versiones instaladas..."
node -v
npm -v

# Crear directorios para el proyecto
echo "Configurando el proyecto..."
mkdir -p ~/whatsapp-bot
cd ~/whatsapp-bot

# Inicializar el proyecto de Node.js
echo "Inicializando el proyecto Node.js..."
npm init -y

# Instalar dependencias necesarias, incluyendo AdminJS
echo "Instalando dependencias..."
npm install express @adiwajshing/baileys body-parser jsonwebtoken bcryptjs adminjs @adminjs/express

# Crear archivo del servidor
echo "Creando archivo del servidor..."
cat > server.js <<EOF
const express = require('express');
const bodyParser = require('body-parser');
const { default: makeWASocket, useMultiFileAuthState } = require('@adiwajshing/baileys');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const AdminJS = require('adminjs');
const AdminJSExpress = require('@adminjs/express');
const app = express();
const port = 3000;

app.use(bodyParser.json());

// Configuración de sesión del bot
const sessionDirectory = './whatsapp-session';
const { state, saveCreds } = useMultiFileAuthState(sessionDirectory);

const sock = makeWASocket({
    auth: state,
    printQRInTerminal: true # Mostrar QR en la terminal para escanearlo
});

sock.ev.on('creds.update', saveCreds);

# Ruta para enviar mensajes
app.post('/send-message', async (req, res) => {
    const { to, message } = req.body;
    try {
        await sock.sendMessage(to, { text: message });
        res.status(200).send('Message sent');
    } catch (error) {
        res.status(500).send('Error sending message');
    }
});

# Ruta para login (simplificada)
app.post('/login', async (req, res) => {
    const { username, password } = req.body;
    # Lógica de autenticación simplificada
    const user = { id: 1, username: 'user', password: '$2a$10$...' }; # Ejemplo de usuario
    if (user && bcrypt.compareSync(password, user.password)) {
        const token = jwt.sign({ id: user.id }, 'your_secret_key');
        res.json({ token });
    } else {
        res.status(401).send('Unauthorized');
    }
});

# Middleware de autenticación
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    if (token == null) return res.sendStatus(401);
    jwt.verify(token, 'your_secret_key', (err, user) => {
        if (err) return res.sendStatus(403);
        req.user = user;
        next();
    });
}

app.use(authenticateToken);

# Configuración de AdminJS
const adminJs = new AdminJS({
    databases: [],
    rootPath: '/admin',
});

const router = AdminJSExpress.buildRouter(adminJs);
app.use(adminJs.options.rootPath, router);

app.listen(port, () => {
    console.log(\`Servidor corriendo en http://localhost:\${port}\`);
    console.log(\`AdminJS disponible en http://$DOMAIN/admin\`);
});
EOF

# Iniciar el servidor de Node.js
echo "Iniciando el servidor..."
cd ~/whatsapp-bot
nohup node server.js > server.log 2>&1 &

echo ""
echo "========================================"
echo "       Instalación completa"
echo "========================================"
echo "El servidor está corriendo en http://$DOMAIN"
echo "El dashboard de AdminJS está disponible en http://$DOMAIN/admin"
echo "Revisa el archivo server.log para ver los detalles de ejecución."
