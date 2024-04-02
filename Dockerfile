#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
FROM eclipse-temurin:17-jre-jammy

ARG spark_uid=1000

RUN groupadd --system --gid=${spark_uid} spark && \
    useradd --system --uid=${spark_uid} --gid=spark spark

RUN set -ex; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y gnupg2 wget bash tini libc6 libpam-modules krb5-user libnss3 procps net-tools gosu libnss-wrapper python3 python3-pip; \
    mkdir -p /opt/hadoop; \
    mkdir -p /opt/spark; \
    mkdir /opt/spark/python; \
    mkdir -p /opt/spark/examples; \
    mkdir -p /opt/spark/work-dir; \
    chmod g+w /opt/spark/work-dir; \
    touch /opt/spark/RELEASE; \
    chown -R spark:spark /opt/spark; \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su; \
    rm -rf /var/lib/apt/lists/*

# Install Hadoop
ENV HADOOP_TGZ_URL=https://dlcdn.apache.org/hadoop/common/hadoop-3.4.0/hadoop-3.4.0-aarch64.tar.gz \
	HADOOP_TGZ_ASC_URL=https://dlcdn.apache.org/hadoop/common/hadoop-3.4.0/hadoop-3.4.0-aarch64.tar.gz.asc \
	HADOOP_KEYS_URL=https://downloads.apache.org/hadoop/common/KEYS

RUN set -ex; \
	export HADOOP_TMP="$(mktemp -d)"; \
	cd $HADOOP_TMP; \
	wget -nv -O KEYS "$HADOOP_KEYS_URL"; \
	wget -nv -O hadoop.tar.gz "$HADOOP_TGZ_URL"; \
	wget -nv -O hadoop.tar.gz.asc "$HADOOP_TGZ_ASC_URL"; \
	gpg --import KEYS; \
	gpg --verify hadoop.tar.gz.asc; \
	mkdir hadoop && tar -xf hadoop.tar.gz -C hadoop --strip-components=1; \
	chown -R spark:spark .; \
	mv hadoop /opt; \
	rm -rf "$HADOOP_TMP";

# Update hadoop-env.sh
RUN sed -i 's/^# export HADOOP_CLASSPATH="\/some\/cool\/path\/on\/your\/machine"$/export HADOOP_CLASSPATH="$HADOOP_HOME\/share\/hadoop\/tools\/lib\/*"/' /opt/hadoop/etc/hadoop/hadoop-env.sh && \
	sed -i 's/^# export HADOOP_OPTIONAL_TOOLS="hadoop-azure-datalake,hadoop-aliyun,hadoop-azure,hadoop-aws,hadoop-kafka"$/# export HADOOP_OPTIONAL_TOOLS="hadoop-azure-datalake,hadoop-azure"/' /opt/hadoop/etc/hadoop/hadoop-env.sh


# Install Apache Spark
# https://downloads.apache.org/spark/KEYS
ENV SPARK_TGZ_URL=https://archive.apache.org/dist/spark/spark-3.5.1/spark-3.5.1-bin-without-hadoop.tgz \
    SPARK_TGZ_ASC_URL=https://archive.apache.org/dist/spark/spark-3.5.1/spark-3.5.1-bin-without-hadoop.tgz.asc \
    GPG_KEY=FD3E84942E5E6106235A1D25BD356A9F8740E4FF

RUN set -ex; \
    export SPARK_TMP="$(mktemp -d)"; \
    cd $SPARK_TMP; \
    wget -nv -O spark.tgz "$SPARK_TGZ_URL"; \
    wget -nv -O spark.tgz.asc "$SPARK_TGZ_ASC_URL"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-key "$GPG_KEY" || \
    gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "$GPG_KEY"; \
    gpg --batch --verify spark.tgz.asc spark.tgz; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" spark.tgz.asc; \
    \
    tar -xf spark.tgz --strip-components=1; \
    chown -R spark:spark .; \
    mv jars /opt/spark/; \
    mv bin /opt/spark/; \
    mv sbin /opt/spark/; \
    mv kubernetes/dockerfiles/spark/decom.sh /opt/; \
    mv examples /opt/spark/; \
    mv kubernetes/tests /opt/spark/; \
    mv data /opt/spark/; \
    mv python/pyspark /opt/spark/python/pyspark/; \
    mv python/lib /opt/spark/python/lib/; \
    mv R /opt/spark/; \
    chmod a+x /opt/decom.sh; \
    cd ..; \
    rm -rf "$SPARK_TMP";

COPY entrypoint.sh /opt/

ENV SPARK_HOME /opt/spark
ENV HADOOP_HOME /opt/hadoop

WORKDIR /opt/spark/work-dir

USER spark

# Install Hadoop Jars
#RUN wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure-datalake/3.4.0/hadoop-azure-datalake-3.4.0.jar -P /opt/hadoop/share/hadoop/tools/lib && \
#       wget https://repo1.maven.org/maven2/com/azure/azure-identity/1.11.4/azure-identity-1.11.4.jar -P /opt/hadoop/share/hadoop/tools/lib

ENTRYPOINT [ "/opt/entrypoint.sh" ]
