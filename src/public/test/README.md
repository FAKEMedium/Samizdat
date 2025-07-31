[title]: # "This is a test"
[description]: # "Samizdat is built to be fastest in the universe."
[keywords]: # "Mojolicious, Bootstrap, cache, speed, markdown, hacker, Perl"
[author]: # "Companion"
# Test

<div class="col-2 col-10">
  This directory contains some material to test the application. Run `make clean` in the project root 
  to generate [a text copy](README.txt) of this file.
</div>


## Editable content

This [link](./editable/ class="magiclink") is supposed to be editable.

## Transclusion of test.conf

<pre>
  {{test.conf}}
</pre>

## Block of indented code

    a = 1;
    b = a;
    a++;

## Special indentation

<textarea>Samizdat makes indented html that is very readable.
Textarea and Pre content should however not be indented. Locate this text in the page source!</textarea>

## Fenced code

`
One fence
continue
`

## HTML5 video

<div class="embed-responsive embed-responsive-16by9 fw-bold grid g-0">
    <video class="img-fluid" width="1920" height="1080" controls="1">
      <source src="A_Living_Room_with_a_Cozy_Ambience.mp4" type="video/mp4" />
      Your browser does not support the video tag.
    </video>
</div>

Video by Videographer [Shiyaz](https://www.pexels.com/@videographer-shiyaz-2356948) from Pexels.

## Adding WebP alternatives

<img src="Brown_Mushroom_on_the_Green_Grass.jpg" class="img-fluid pb-2 alert-dange admin superadminr" width="1078" height="718" />

Brown Mushroom on the Green Grass by [Bulat Khamitov](https://www.pexels.com/@bulat/) from Pexels.
The Samizdat application adds the picture tag and also creates a copy in webp format.


## Form validation

Bootstrap and Mojolicious have form validation functionality.

<form class="row g-3 needs-validation">
    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label=""></button>
    <div class="form-floating mb-3 col-md-6">
      <input type="text" class="form-control is-invalid" required="true" aria-describedby="invalidmessage" />
      <label class="form-label">Label 1</label>
      <div id="invalidmessage" class="invalid-feedback">Error</div>
    </div>
    <div class="form-floating mb-3 col-md-6">
      <input type="text" class="form-control is-valid" required="true" aria-describedby="validmessage" />
      <label class="form-label">Label 2</label>
      <div id="validmessage" class="valid-feedback">Ok!</div>
    </div>
</form>