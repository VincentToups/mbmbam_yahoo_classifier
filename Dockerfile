FROM centos:7
MAINTAINER Vincent Toups "vincent.toups@xyleminc.com"
RUN yum -y groupinstall 'Development Tools'
RUN yum install -y\
        curl\
        cyrus-sasl-devel\
        java-1.8.0-openjdk\
        openssl-devel\
        openssl\
        sqlite\
        sqlite-devel\
        sqlite\
        wget\
        which\
        zlib-devel
COPY install-python-3.6.sh /
RUN bash install-python-3.6.sh
RUN python3 -m ensurepip
RUN pip3 install Pweave --upgrade
RUN pip3 install Unidecode --upgrade
RUN pip3 install git+https://github.com/Calysto/calysto_hy.git --upgrade
RUN pip3 install git+https://github.com/ekaschalk/jedhy.git --upgrade
RUN pip3 install git+https://github.com/hylang/hy.git@0.15.0 --upgrade
RUN pip3 install jupyter --upgrade
RUN pip3 install keras --upgrade
RUN pip3 install matplotlib --upgrade
RUN pip3 install mlblocks[demo] --upgrade
RUN pip3 install mlblocks --upgrade
RUN pip3 install mlprimitives --upgrade
RUN pip3 install nltk --upgrade
RUN pip3 install numpy --upgrade
RUN pip3 install pandas --upgrade
RUN pip3 install pandasql --upgrade
RUN pip3 install plotly --upgrade
RUN pip3 install plotnine --upgrade
RUN pip3 install pyamg --upgrade
RUN pip3 install pymongo --upgrade
RUN pip3 install pytest --upgrade
RUN pip3 install python-Levenshtein --upgrade
RUN pip3 install requests --upgrade
RUN pip3 install sasl --upgrade
RUN pip3 install scipy==1.2 --upgrade
RUN pip3 install sklearn --upgrade
RUN pip3 install tensorflow --upgrade
RUN pip3 install thrift-sasl --upgrade
RUN pip3 install thrift --upgrade
RUN python3 -m calysto_hy install
RUN yum -y install epel-release
RUN yum -y install nodejs
RUN npm install --global\
        bluebird\
        cheerio\
        condense-whitespace\
        file-exists\
        md5\
        restler\
        stopword\
        text2token\
        url-parse\
        wink-nlp-utils\
        wink-tokenizer\
        query-string\
        urldecode\
        yargs
RUN npm install --global @kba/makefile-parser
ARG NODE_PATH_BT=/usr/lib/node_modules
ENV NODE_PATH=$NODE_PATH_BT
WORKDIR /host
CMD /bin/bash
