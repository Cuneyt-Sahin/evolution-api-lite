########################
# 1) BUILDER
########################
FROM node:24-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl

WORKDIR /evolution

COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./

RUN npm ci --silent

COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./.env.example ./.env
COPY ./runWithProvider.js ./
COPY ./Docker ./Docker

RUN cp ./prisma/postgresql-schema.prisma ./prisma/schema.prisma
RUN sed -i 's/provider = "postgresql"/provider = "sqlite"/g' ./prisma/schema.prisma
RUN sed -i 's/@db\.VarChar([0-9]*)//g' ./prisma/schema.prisma && \
    sed -i 's/@db\.VarChar//g' ./prisma/schema.prisma && \
    sed -i 's/@db\.Text//g' ./prisma/schema.prisma && \
    sed -i 's/@db\.JsonB//g' ./prisma/schema.prisma && \
    sed -i 's/@db\.Timestamp(6)//g' ./prisma/schema.prisma && \
    sed -i 's/@db\.Timestamp//g' ./prisma/schema.prisma && \
    sed -i 's/@db\.Boolean//g' ./prisma/schema.prisma && \
    sed -i 's/@db\.Integer//g' ./prisma/schema.prisma && \
    sed -i 's/@db\.DoublePrecision//g' ./prisma/schema.prisma && \
    sed -i 's/@db\.Oid//g' ./prisma/schema.prisma && \
    sed -i 's/@db\.Inet//g' ./prisma/schema.prisma && \
    sed -i 's/@db\.Date//g' ./prisma/schema.prisma

RUN npx prisma generate

# Lite için build script’ini sadece tsup yap
RUN node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json','utf8'));p.scripts.build='tsup';fs.writeFileSync('package.json',JSON.stringify(p,null,2));"

RUN npm run build

########################
# 2) FINAL IMAGE
########################
FROM node:24-alpine AS final

RUN apk update && \
    apk add tzdata ffmpeg bash openssl

WORKDIR /evolution

COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/tsup.config.ts ./tsup.config.ts

EXPOSE 8080

CMD ["npm", "run", "start:prod"]
