import subprocess

def RunKaldiCommand(command, wait = True):
    """ Runs commands frequently seen in Kaldi scripts. These are usually a
        sequence of commands connected by pipes, so we use shell=True """
    #logger.info("Running the command\n{0}".format(command))
    p = subprocess.Popen(command, shell = True,
                         stdout = subprocess.PIPE,
                         stderr = subprocess.PIPE)

    if wait:
        [stdout, stderr] = p.communicate()
        if p.returncode is not 0:
<<<<<<< Updated upstream
            raise Exception("There was an error while running the command {0}\n------------\n{1}".format(command, stderr))
=======
            out=stderr if len(stderr)>0 else stdout
            raise Exception("There was an error while running the command {0}\n".format(command)+"-"*10+"\>>noutput:\n"+out)
>>>>>>> Stashed changes
        return stdout, stderr
    else:
        return p
