% Framework for auditory modeling based on Bayesian inference
% 
%   FrAMBI is a flexible framework to help scientists to develop 
%   and test mechanisms of hearing perception using Bayesian statistics. 
%   At its heart, the framework relies on computational statistics 
%   to support the assessment of quantitative structural hypotheses 
%   on the processes underlying the human hearing.
%  
%   Main FrAMBI functions: 
%     frambi_estimate        - Estimate model parameters
%     frambi_likelihood      - Calculate the model's likelihood
%     frambi_sample          - Sample the response distribution
%     frambi_simulate        - Simulate a perception-action cycle
%     frambi_test            - Test model variants
%
%   FrAMBI helpers:
%     frambi_disp              - Display the log information
%     frambi_parameters        - Add, remove, and check model parameters
%     frambi_plot              - Plot the log information
%     frambi_validate          - Validate a FrAMBI structure
%
%   Examples can be found in |exp_barumerli2024|, which uses two example models  
%   |barumerli2024_itdlateral| and |barumerli2024_mockup| as well as example for an
%   environment |sig_barumerli2024|. 
%
%
%   Overview
%   --------
% 
%   The core of the framework is |frambi_simulate|. If we draw a parallel with a 
%   behavioral experiment with a subject, |frambi_simulate| corresponds to a single
%   trial in the experiment and we call |frambi_simulate| repetitively for as many 
%   trials as considered in the experiment. 
%
%   An example of using |frambi_simulate| can be found in |exp_barumerli2024|.
%
%   |frambi_simulate| takes two structures as input: the agent 
%   and the environment. Both structures contain the following fields: 
%
%   + *name*: String with a name of the agent or environment.
%
%   + *type*: String defining the type of the structure. 
%
%   + *state*: Structure describing the state of the agent or environment. 
%
%   + *model*: Structure describing the functions of the agent or environment.
%
%   
%   Additionally, FrAMBI uses a structure defining various options of the experiment. 
%   All these structures are supposed to be created by the functions implementing the agent and the environment. 
%   Options can be created by calling |frambi_validate| without any input parameter. 
%
%   The Agent 
%   --------- 
%
%   Within the AMT, an agent corresponds to a model. Consequently, the agents 
%   are defined by functions located in the directory `models`. There, the agent main 
%   function needs to create the agent's structure with the following fields: 
%
%   + *name*: String with the name of the agent. 
%
%   + *type*: String defining the type of the structure. 
%
%   + *state*: Structure describing the states of the agent with the following fields: 
%
%     + *parameters*: Structure describing the agent's parameters. For details, see |frambi_parameters|. 
%
%     + *observation*, *beliefs*, and *action*: Optional field with the results
%       of agent's behavior. They will be created by |frambi_sample| and can be
%       optionally set up by the agent's main function. 
%
%   + *model*: Structure with the following fields defining the agent's behavior: 
%
%     + *initialize*: Function handle to a function performing initializing  
%       the agent at the begin of each trial.
%
%     + *observe*: Function handle to a function observing the environment based on 
%       the signal delivered by the environment.
%
%     + *infer*: Function handle to a function infering the environment's hidden states
%       based on the obesrvation. 
%
%     + *act*: Function handle to a function acting according to the infered states.
%
%     + *respond*: Function handle to a function responding to the experimentator
%       when a trial is completed.   
%
%   The function handles that are stored in *model* can be local functions within the agent.
%
%   Note that when |frambi_validate| is called before the exit, *model*
%   is the only required field because |frambi_validate| can create all the missing fields. 
%   Thus a minimalistic definition of the agent structure is::
%
%     agent.model = [];
%     agent = frambi_validate(agent);
%   
%   Two examples of an agent can be found in |barumerli2024_itdlateral| and |barumerli2024_mockup|. 
% 
%
%   The Environment
%   ---------------
%
%   Within the AMT, an environment corresponds to creating signals to be used by models. 
%   Consequently, the environments are defined by functions located in the directory `signals`
%   and have the prefix `sig_`. There, the environment main function needs to create the 
%   environments's structure with the following fields: 
%
%   + *name*: String with the name of the environment. 
%
%   + *type*: String defining the type of the structure. 
%
%   + *state*: Structure describing the states of the environment with the following fields: 
%
%     + *parameters*: Structure describing the environments's parameters. For details, see |frambi_parameters|. 
%
%     + *output*: Structure with the output generated by the environment to be observed
%       by the agent. This field is optional in the main function, but it must be provided
%       by the *execute* function. 
%
%     + Other fields with internal variables for the environment's work. 
%
%   + *model*: Structure with the following fields defining the environment's behavior: 
%
%     + *initialize*: Function handle to a function performing initializing  
%       the environment at the begin of each trial.
%
%     + *execute*: Function handle to a function creating the signal delivered to the agent.
%
%     + *conclude*: Function handle to a function concluding whether the trial has reached its end. 
%       It must return `true` if the trial has been finished.
%
%   The function handles that are stored in *model* can be local functions within the environment.
%
%   Note that when |frambi_validate| is called before the exit, *model.execute* is
%   the only required field because |frambi_validate| can create all the other fields. Thus a 
%   minimalistic definition of the environment structure is::
%
%     environment.model.execute = [];
%     environment = frambi_validate(environment);
%   
%   An example of two environments can be found in |sig_barumerli2024|. 
%   
%
%   First steps
%   -----------
%    
%   **Create an experiment:** To begin with FrAMBI, create a file in the directory `experiments`
%   with the prefix `exp_`. There, create a function, in which:
%    
%   + Call the definition of the agent (the entity that simulates the subject's behavior).
%
%   + Call the definition of the environment (representing the experimental conditions such as sound sources and their movement).
%
%   + Configure the options such as the number of repetitions or specific settings for the simulation.
%
%   |exp_barumerli2024| implements several experiments, it might be a good started and a template.
%    
%   **Create the agent:** Create a function in the directory `models`. |barumerli2024_itdlateral| 
%   and |barumerli2024_mockup| implement two agents and these files can be used as a template. 
%    
%   **Create the environment:** Create a function in the directory `signals` with the prefix `sig_`. 
%   This function will simulated the external conditions of the experiment, 
%   like sound sources and define how they interact with the agent. |sig_barumerli2024| implements 
%   two environments and might server as a template.
%   
%   **Expand the experiment:** Back to your experiment function `exp_`, implement the run 
%   of the simulation by means of calling |frambi_simulate|, e.g., ::
%   
%     [response, logs] = frambi_simulate(agent, environment, options); 
%   
%   This code will execute a single trial, triggering the interaction between agent and environment, 
%   and returning the agent’s *response* and *logs* of the process.
%  
%   **Visualize the results:** Plot and/or display the results using |frambi_plot| and/or |frambi_disp|.
%   These functions help in analyzing the agent's behavior over time and the interaction between 
%   the agent and the environment, e.g., ::
%   
%     frambi_plot(logs,  {'beliefs', 'action'},  {'angle', 'time'}); 
%   
%   In this example, |frambi_plot| creates a plot that shows the evolution 
%   of the agent's beliefs and actions, along with the environment's angle and time.
%
%   To display a detailed step-by-step log of the simulation, 
%   including the state of both the agent and the environment during each cycle, use ::
%
%     frambi_disp(logs, 1);
%
%
%   For more information, see the documentation of other functions and Barumerli and Majdak (2024). 
  
