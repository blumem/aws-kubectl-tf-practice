# *************************************************************************************
# Stage 1: build the spring-boot app using a Maven image
# *************************************************************************************
FROM jumpserver/maven:3.9.2-openjdk-17-slim AS build

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY demo/pom.xml  .
COPY demo/src ./src

# BUILD the app
RUN mvn clean install -DskipTests
# strip the jar into layers to speed up the docker build
RUN mkdir target/extracted
RUN java -Djarmode=layertools -jar target/*jar extract --destination target/extracted

# *************************************************************************************
# Stage 2: build the final image using a smaller java image maintained by AWS java team
# *************************************************************************************
FROM --platform=linux/amd64 amazoncorretto:17-alpine-jdk AS final
WORKDIR /app
COPY --from=build /app/target/extracted/dependencies/ ./
COPY --from=build /app/target/extracted/spring-boot-loader/ ./
COPY --from=build /app/target/extracted/snapshot-dependencies/ ./
COPY --from=build /app/target/extracted/application/ ./
EXPOSE 8080
ENTRYPOINT [ "java", "org.springframework.boot.loader.launch.JarLauncher" ]
# alternative if we don't split the layers we can just use:
# advantage of layers is faster docker build times as old layers can be kept if no changes are made
#COPY --from=build /app/target/*.jar app.jar
#CMD ["java", "-jar", "app.jar"]