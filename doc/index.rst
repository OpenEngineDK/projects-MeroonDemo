Welcome to OpenEngine's documentation!
======================================

This is the documentation for the new OpenEngine built on Scheme.
Please add your descriptions of your thoughts and code while they
evolve.

Contents:

.. toctree::
   :maxdepth: 2

   intro-scheme
   intro-meroon
   intro-gambit
   scene
   features-and-files

Installing and building the documentation
-----------------------------------------

To build the doc install sphinx and graph the current scheme
extension:

.. code-block:: bash

   sudo apt-get install python-setuptools
   sudo easy_install -U Sphinx
   sudo easy_install -U pygments
   wget http://openengine.dk/data/sphinx-contrib.tar.gz
   tar zxvf sphinx-contrib.tar.gz
   cd sphinx-contrib/schemedomain
   python setup.py build
   sudo python setup.py install

After that you can cd to these docs and run: `make html`,
and open _build/html/index.html in your browser.


Indices and tables
==================

* :ref:`genindex`
* :ref:`search`

.. * :ref:`modindex`
