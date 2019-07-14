Introduction
============

Let's build a text LSTM classifier for My Brother, My Brother and Me's
Yahoo Answer Questions.

Requirements
============

Docker.

Running Things
==============

Everything here is orchestrated via a Makefile.

Build The Environment
---------------------

    > docker build . -t mbmbam-ya
    
Running Jobs
------------

    > docker run -v `pwd`:/host -it make list
    
To get a list of make tasks.

