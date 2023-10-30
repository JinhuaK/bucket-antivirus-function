FROM public.ecr.aws/lambda/python:3.11

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt

# Install packages
RUN yum update -y \
  && yum install -y cpio yum-utils zip unzip less \
  && yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN pip install -r requirements.txt
RUN rm -rf /root/.cache/pip

# Download libraries we need to run in lambda
WORKDIR /tmp
RUN yumdownloader -x \*i686 --archlist=x86_64 clamav \
  clamav-lib \
  clamav-update \
  json-c \
  pcre2 \
  libprelude \
  gnutls \
  libtasn1 \
  lib64nettle \
  nettle \
  binutils \
  libtool-ltdl \
  libxml2 \
  libcurl \
  xz-libs \
  libnghttp2 \
  libidn2 \
  libssh2
RUN rpm2cpio clamav-0*.rpm | cpio -idmv
RUN rpm2cpio clamav-lib*.rpm | cpio -idmv
RUN rpm2cpio clamav-update*.rpm | cpio -idmv
RUN rpm2cpio json-c*.rpm | cpio -idmv
RUN rpm2cpio pcre*.rpm | cpio -idmv
RUN rpm2cpio libprelude* | cpio -idmv
RUN rpm2cpio gnutls* | cpio -idmv
RUN rpm2cpio nettle* | cpio -idmv
RUN rpm2cpio lib* | cpio -idmv
RUN rpm2cpio libtasn1* | cpio -idmv
RUN rpm2cpio binutils* | cpio -idmv
RUN rpm2cpio libtool-ltdl* | cpio -idmv
RUN rpm2cpio libxml2* | cpio -idmv
RUN rpm2cpio libcurl* | cpio -idmv
RUN rpm2cpio xz-libs* | cpio -idmv
RUN rpm2cpio libnghttp2* | cpio -idmv
RUN rpm2cpio libidn2* | cpio -idmv
RUN rpm2cpio libssh2* | cpio -idmv

# Copy over the binaries and libraries
RUN cp /tmp/usr/bin/clamscan /tmp/usr/bin/freshclam /tmp/usr/bin/ld.bfd /tmp/usr/lib64/* /opt/app/bin/

# Copy libraries included in the base image but not present in the lambda runtime python3.11
RUN cp /lib64/libpcre.so.1 \
  /usr/lib64/libldap-2.4.so.2 \
  /usr/lib64/liblber-2.4.so.2 \
  /usr/lib64/libunistring.so.0 \
  /usr/lib64/libsasl2.so.3 \
  /usr/lib64/libssl3.so \
  /usr/lib64/libsmime3.so \
  /usr/lib64/libnss3.so \
  /usr/lib64/libcrypt.so.1 \
  /opt/app/bin/

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip *.py bin

WORKDIR /var/lang/lib/python3.11/site-packages
RUN zip -r9 --exclude="*boto*" /opt/app/build/lambda.zip *