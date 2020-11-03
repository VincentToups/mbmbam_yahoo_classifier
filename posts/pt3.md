Pt 3: Data Science
==================

Last time we pulled our data set - hundreds of questions from Yahoo
Answers, submitted to My Brother, My Brother, and Me and accepted. We
also pulled thousands of random questions from Yahoo Answers to use as
a control set. 

We're finally ready to start doing some _real_ data science. And our
first step is deduplication.

Deduplication
-------------

It may not seem like a huge deal, but duplicates in a data set can
really trip you up. For one thing, they can skew descriptive
statistics. But the big issue is that during validation, we typically
do some form of train/test split. Models can _overfit_ on their
training data and so we need some way to evaluate how they _would_
perform on totally new data, which is also, typically, much more in
line with how we want to use the model anyway.

In our case, we're not really interested in how well our model is
going to predict whether _old_ questions would make it on the podcast
(after all, we already know that). We're really interested in whether
_new_ questions would. We can simulate new questions by just setting
aside a random set of questions and training our model on the rest -
the set aside questions are _new_ as far as the model is concerned.

_Except_ when there are duplicates in our data set. If we do have
duplicates, then our randomly selected test set is likely to contain
values that are actually in out training data. A model could, for
instance, substantially improve its performance, in such a situation,
by just remembering every single data point in the training data and
regurgitating the appropriate categorization whenever it sees one. 

Duplicates make this kind of overfitting seem like a good strategy,
and they hide how poorly a model performs on non-duplicate data.

So, good data scientists should de-duplicate. 

We actually _did_ try to do this in our scraping phase - each Yahoo
Answers question has a question ID, and we made sure never to store
the same question twice.

However, I know from experience that this doesn't catch all duplicates
so we want to do a pre-screening pass to remove obvious duplicates now
and hopefully save ourselves some headaches later. 

We've got a fair number of data points to work with here, so we can
afford to be slightly aggressive. But first...

Hy What?
========

From here out we're going to be doing our data analysis in
Python... sort of. We're actually going to use Hy, a Python hosted
Lisp dialect. This is an admittedly quixotic gesture towards
popularizing Lisp-like languages.

[Hy]() is a Lisp which is compiled down to Python bytecode. As such,
semantically, its quite closer to Python than it is to any other Lisp
dialect. If you're familiar with Python, the trick to reading Hy is to
convert expressions like this:

    (f a b c) 
    
To this:

    f(a,b,c)
    
And to note that control operaters as well as functions are denoted
with parentheses, like this:

    (if case a1 a2)
    
Would translate roughly to:

    if case:
        return a1;
    else:
        return a2;
        
I say "roughly" becase in Hy, as in all Lisps, `if` is a value
producing expression (eg, it evaluates to a value). `if` in python is
just for branching.

Anyway, Python is where a lot of the action is at but I really prefer
writing s-expressions so we're using Hy.

Deduplication
=============

Our strategy is going to be extremely simple. We're going to grab the
questions, sanitize the text somewhat by tokenizing it, removing stop
words, and moving everything to lower case, and then we're going to
use the Levenshtein string metric to compare all of our strings. Once
we've done that we'll select a conservative threshold and throw away
any duplicates that we get.

First we need a few Hy utilities:

    (require [dotdot [chain]])
    (require [hy.contrib.loop [loop]])

And we want to use the TweetTokenizer from the NLTK package.

    (import [Levenshtein [distance]]
            json
            io
            sys
            [numpy :as np]
            [textwrap [fill]]
            [nltk.tokenize.casual [TweetTokenizer]])

We also grabbed a few other things we'll need.

These aren't tweets, but they are pretty similarly informal pieces of
text.

Here is our sanitizer:

    (setv tokenizer (TweetTokenizer :preserve-case False))

    (defn sanitize [question-text]
      (chain " " (join
                  (lfor token (chain tokenizer (tokenize question-text))
                        :if (> (len token) 3)
                        token))))

And now some utilities to load and tag our data:

    (defn load-json [filename]
      (with [f (io.open filename "r" :encoding "ascii")]
            (json.load f)))

    (defn write-json [filename]
      (with [f (io.open filename :mode "w" :encoding "ascii")]
            (f.write (json.dumps exp))))

    (defn tag [tag-value]
      (fn [item]
        (setv (chain item "category") tag-value)
        item))

    (defn has-question? [x]
      (and (in "question" x)
           (not (= "" (chain x "question" (strip))))))

    (defn preprocess [category]
      (fn [dataset]
        (filt
         has-question?
         (mp (tag category) dataset))))

And thus we can now load our data:
    
     (setv data (+ ((preprocess "experimental") 
      (load-json
       "./derived_data/question-info.ascii.json"))
                   ((preprocess "control") 
      (load-json 
       "./derived_data/control-question-info.ascii.json"))))
       
We've concatenated both sets together and tagged each with a "control"
or "experimental" field to distinguish them in future analysis steps.

Here is the idea: we're going to add a list to each entry to hold an
ID (integral) and the duplicates. Then we'll loop through all pairs
(careful not to repeat ourselves) and flag anything as a duplicate if
its less than a threshold distance separates them.

Its handy to generate a histogram of these distances to choose such a
threshold.

    (setv ns (len data))
    (setv distances [])

    (setv i 0)
    (for [datum data]
      (setv (chain datum ["duplicates"]) [])
      (setv (chain datum ["id"]) i)
      (setv (chain datum ["sanitized_question"])
            (sanitize
             (chain datum "question")))
      (setv (chain datum ["sanitized_detail"])
            (sanitize
             (chain datum "detail")))
      (when (not (in "answers" datum))
        (setv (chain datum "answers") []))
      (setv (chain datum ["sanitized_answers"])
            (lfor a (chain datum "answers")
                  (sanitize a)))
      (setv i (+ i 1)))

    (for [i (range ns)]
      (for [j (range (+ 1 i) ns)]
        (setv d (distance
                 (chain data [i] "sanitized_question")
                 (chain data [j] "sanitized_question")))
        (distances.append d)))
    
![Distances](figures/distance-histogram.png)

We'll just eyeball a solution here and choose a threshold which chops
off the bottom part of the lowest lobe in this distribution: say 7 to
chop off the bottom of distribution. Here are some of the duplicates
that it picks up:

    Duplicates:
        should i pay off my credit cards or build an emergency fund first ?
        should i pay off my credit cards or build an emergency fund first ?

    Duplicates:
        bank question ?
        math question ?

    Duplicates:
        what is this plant ?
        what is this plant ?

    Duplicates:
        cast iron pan questions ?
        cast iron pan questions ?

    Duplicates:
        whatis firefox ?
        what is a lemon ?

    Duplicates:
        what older novel ( talking mid to late 90s ) was about toxic waste being illegally dumped & plants were infected & ended up killing everyone ?
        what older novel ( talking mid to late 90s ) was about toxic waste being illegally dumped & plants were infected & ended up killing everyone ?

We'd like to keep as much data as possible, so now that we've labelled
our duplicates, we're going to iterate through everything and grab the
first of every duplicate set.

    (setv collected-map {})
    (setv non-duplicates [])
    (for [datum data]
      (setv id (chain datum "id"))
      (when (not (in id collected-map))
        (setv (chain collected-map [id]) True)
        (for [duplicate-id (chain datum "duplicates")]
          (setv (chain collected-map [duplicate-id]) True))
        (chain non-duplicates (append datum))))

    (write-json non-duplicates "./derived_data/deduplicated.json")

Now we just add our Make target:

    ./derived_data/deduplicated.json:\
     ./derived_data/question-info.ascii.json\
     ./derived_data/control-question-info.ascii.json
        hy deduplicate.hy

And we're ready for 

### Featurization

Allright, we've got to bang these questions into some sort of shape
simple enough for a dumb computer to understand. In the previous step
we tokenized our questions, downcased them, and reconcatenated
them. We'd like to go even further now. Our strategy will be to
re-tokenize them and loop _all_ the words, assigning each word a
unique identifier. We'll also need an identifier which means "nothing"
and one which means "unknown". Why the former? So that we can fill the
encoding of short sentences with the "nothing" identifier. Why the
latter? So when we apply the classifier to a new data set we can
"gracefully" handle words that aren't in our training set.

The whole thing is pretty simple

    (require [dotdot [chain]])
    (require [hy.contrib.loop [loop]])
    (import io
            json)

    (setv encoding {"--unknown--" 0
                    "--stop--" 1})
    (setv decoding {0 "--unknown--"
                    1 "--stop--"})

    (setv last-encoded 1)

    (defn load-json [filename]
      (print (chain "input: {}" (format filename)))
      (with [f (io.open filename "r" :encoding "ascii")]
            (json.load f)))

    (defn write-json [exp filename]
      (print (chain "output: {}" (format filename)))
      (with [f (io.open filename :mode "w" :encoding "ascii")]
            (f.write (json.dumps exp :indent 1))))

    (setv data (load-json "./derived_data/deduplicated.json"))
    (setv max-encoded-length 0)
    (for [datum data]
      (setv tokens (chain datum "sanitized_question" (split " ")))
      (setv encoded-question [])
      (for [token tokens]
        (when (not (= "" token))
          (when (not (in token encoding))
            (setv (chain encoding [token]) (+ 1 last-encoded))
            (setv (chain decoding [(+ 1 last-encoded)]) token)
            (setv last-encoded (+ 1 last-encoded)))
          (chain encoded-question (append (chain encoding [token])))))
      (when (> (len encoded-question) max-encoded-length)
        (setv max-encoded-length (len encoded-question)))
      (setv (chain datum "encoded_question") encoded_question))

    ;; Pad the encoded representations with the stop value

    (for [datum data]
      (setv e (chain datum "encoded_question"))
      (setv pad-n (- max-encoded-length (len e)))

      (setv (chain datum "encoded_question")
            (+ e
               (* [(chain encoding "--unknown--")]
                  pad-n))))

    (write-json { "max-encoded-length" max-encoded-length
                  "encoding" encoding
                  "decoding" decoding}
                "./derived_data/encoding-information.json")
    (write-json data "./derived_data/encoded.json")

This featurization is simple and relatively straightforward. In the
next post we'll use it to analyze our data in a few different ways.
