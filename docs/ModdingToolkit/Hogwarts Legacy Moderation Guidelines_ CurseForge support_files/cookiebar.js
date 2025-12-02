function initCookiebar() {
  if (document.cookie.split(';').filter((item) => item.includes('cf_cookieBarHandled=')).length) {
      return
  }

  const html = `
<style>
  .cookiebar {
      z-index: 2147483001;
      bottom: -6px;
      position: fixed;
      width: 100%;
      border: 0;
      border-top: solid 1px #CCCCCC;
      background: #E5E5E5;
      box-sizing: border-box;
      transform: translateY(0);
      transition: .6s cubic-bezier(.65,-0.29,.28,1.25);
  }
  .cookiebar.collapsed {
      pointer-events: none;
      transform: translateY(68px);
      opacity: 0;
  }
  .cookiebar-content {
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 16px 0 26px;    /* +10px bottom for transition */
      font-family: 'Lato', sans-serif;
  }
  .cookiebar span {
      color: #0D0D0D !important;
      padding-right: 32px;
      text-align: center;
      font-size: 16px;
      line-height: 23px;
  }
  .cookiebar a {
      color: #0D0D0D !important;
      text-decoration: underline;
      transition: .15s color;
      cursor: pointer;
  }
  .cookiebar a:hover {
      color: #0D0D0D;
  }
  #cookiebar-ok {
      cursor: default;
      display: block;
      width: 80px;
      height: 36px;
      font-size: 16px;
      background: #F16436;
      color: #ffffff !important;
      border: 0;
      transition: .15s background;
      text-align: center;
      display: flex;
      align-items: center;
      justify-content: center;
  }
  #cookiebar-ok:hover {
      background: #FF784D;
  }

  @media (max-width: 1530px) {
      .cookiebar-content {
          flex-direction: column;
          width: 90%;
          margin: 24px auto 34px; /* +10px bottom for transition */
      }
      .cookiebar span {
          padding-right: 0;
          padding-bottom: 20px;
      }
  }
</style>
<div id="cookiebar" class="cookiebar collapsed">
  <div class="cookiebar-content">
      <span>We use cookies to improve your experience and increase the relevancy of content when using CurseForge. Our cookies are used for analytics,<br>optimization, and advertising operations. <a target="_blank" href="https://legal.overwolf.com/docs/overwolf/cookies-policy">View our Cookies Policy</a></span>
      <div role="button" id="cookiebar-ok" style="color: #ffffff !important;">Got it</div>
  </div>
</div>`;

  document.body.insertAdjacentHTML("beforeend", html);

  const cookiebar = document.getElementById("cookiebar");
  const cookiebarOk = document.getElementById("cookiebar-ok");
  setTimeout(() => {
      cookiebar.classList.remove("collapsed");
  }, 1000);
  cookiebarOk.addEventListener("click",() => {
      let cookieDomain = location.hostname === 'localhost'
        ? location.hostname
        : `.${location.hostname}`;
      let cookieName = 'cf_cookieBarHandled';
      let cookieValue = 'true';
      let myDate = new Date();
      myDate.setFullYear(myDate.getFullYear() + 1);
      document.cookie = cookieName +"=" + cookieValue + ";expires=" + myDate.toUTCString() + ";domain=" + cookieDomain + ";path=/;secure";

      cookiebar.classList.add("collapsed");
  });
}

// This test is necessary because pages like the dev site might rerun the js
function wasCookiebarAlreadyInitialized() {
  if (document.getElementById("cookiebar")) {
      return true;
  } else {
      return false;
  }
}

if(document.readyState === "interactive" ||
    document.readyState === "complete") {
  if (!wasCookiebarAlreadyInitialized()) {
      initCookiebar();
  }
}
else {
  function initCookiebarAndUnregisterEventListener() {
      if (!wasCookiebarAlreadyInitialized()) {
          initCookiebar();
      }
      document.removeEventListener("DOMContentLoaded", initCookiebarAndUnregisterEventListener);
  }
  document.addEventListener("DOMContentLoaded", initCookiebarAndUnregisterEventListener, false);
}