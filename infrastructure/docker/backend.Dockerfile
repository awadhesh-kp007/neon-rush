FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN ./mvnw -q package -DskipTests --no-transfer-progress 2>/dev/null || \
    (apt-get update -qq && apt-get install -y -qq maven && mvn -q package -DskipTests --no-transfer-progress)

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -S neonrush && adduser -S neonrush -G neonrush
COPY --from=builder /app/target/*.jar app.jar
USER neonrush
EXPOSE 8080
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", \
            "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
